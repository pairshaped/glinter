import argv
import glance
import gleam/dict
import gleam/io
import gleam/list
import gleam/option.{None, Some}
import gleam/string
import glinter/config
import glinter/ffi_usage
import glinter/ignore
import glinter/reporter.{Json, Text}
import glinter/rule
import glinter/rules/assert_ok_pattern
import glinter/rules/avoid_panic
import glinter/rules/avoid_todo
import glinter/rules/deep_nesting
import glinter/rules/discarded_result
import glinter/rules/division_by_zero
import glinter/rules/duplicate_import
import glinter/rules/echo_rule
import glinter/rules/error_context_lost
import glinter/rules/function_complexity
import glinter/rules/label_possible
import glinter/rules/missing_labels
import glinter/rules/missing_type_annotation
import glinter/rules/module_complexity
import glinter/rules/panic_without_message
import glinter/rules/prefer_guard_clause
import glinter/rules/redundant_case
import glinter/rules/short_variable_name
import glinter/rules/string_inspect
import glinter/rules/stringly_typed_error
import glinter/rules/thrown_away_error
import glinter/rules/todo_without_message
import glinter/rules/trailing_underscore
import glinter/rules/unnecessary_string_concatenation
import glinter/rules/unnecessary_variable
import glinter/rules/unqualified_import
import glinter/rules/unwrap_used
import glinter/runner
import glinter/unused_exports
import simplifile

/// Run glinter with extra rules from external packages.
/// Use this from a review.gleam file to add project-specific rules:
///
/// ```gleam
/// import glinter
/// import my_project/rules
///
/// pub fn main() {
///   glinter.run(extra_rules: [
///     rules.no_raw_sql(),
///     rules.require_org_id(),
///   ])
/// }
/// ```
///
/// Extra rules are configured the same way as built-in rules
/// (on/off/severity in gleam.toml, file-level ignores).
pub fn run(extra_rules extra_rules: List(rule.Rule)) -> Nil {
  let start_time = monotonic_time_ms()
  let args = argv.load().arguments
  let #(format, project_prefix, show_stats, paths) = parse_args(args)

  let config_path = project_prefix <> "gleam.toml"
  let cfg = load_config(config_path)
  let show_stats = show_stats || cfg.stats

  let module_rules = list.append(built_in_rules(), extra_rules)

  // Resolve paths: CLI args > config include > default src/
  let effective_paths = case paths {
    [] ->
      case cfg.include {
        [] -> [project_prefix <> "src/"]
        dirs -> list.map(dirs, fn(d) { project_prefix <> d })
      }
    _ -> paths
  }

  // Discover files (absolute paths), then make relative for ignore matching
  // and cleaner output
  let file_paths =
    discover_files(effective_paths)
    |> list.map(fn(f) { strip_prefix(f, project_prefix) })
    |> list.filter(fn(f) { !ignore.is_file_excluded(f, cfg.exclude) })

  // Read and parse files, collecting sources for reporter and cross-module passes
  let #(parsed_files, sources) =
    file_paths
    |> list.fold(#([], []), fn(acc, file_path) {
      let read_path = project_prefix <> file_path
      case simplifile.read(read_path) {
        Error(_) -> {
          io.println_error("Error: Could not read " <> read_path)
          acc
        }
        Ok(source) ->
          case glance.module(source) {
            Error(_) -> {
              io.println_error("Error: Failed to parse " <> read_path)
              acc
            }
            Ok(module) -> #([#(file_path, source, module), ..acc.0], [
              #(file_path, source),
              ..acc.1
            ])
          }
      }
    })
  let parsed_files = list.reverse(parsed_files)
  let sources = list.reverse(sources)

  let all_rules = apply_config(module_rules, cfg)
  let per_file_results =
    runner.run(rules: all_rules, files: parsed_files, config: cfg)

  // Cross-module: unused exports detection (special-cased — needs file paths
  // and src/test distinction that the project rule API doesn't yet provide)
  let unused_export_results =
    run_unused_exports(parsed_files, project_prefix, cfg)
  let results = list.append(per_file_results, unused_export_results)

  // Cross-file: FFI usage detection (special-cased — scans .mjs files,
  // not Gleam AST)
  let ffi_results = run_ffi_usage(effective_paths, project_prefix, cfg)
  let results = list.append(results, ffi_results)

  let elapsed_ms = monotonic_time_ms() - start_time
  let stats =
    reporter.Stats(
      file_count: list.length(sources),
      line_count: count_lines(sources),
      elapsed_ms: elapsed_ms,
    )

  let output = case format {
    Text -> reporter.format_text(results, sources, show_stats, stats)
    Json -> reporter.format_json(results, sources, show_stats, stats)
  }
  io.println(output)

  let has_issues = !list.is_empty(results)
  case has_issues {
    True -> halt(1)
    False -> halt(0)
  }
}

pub fn main() {
  run(extra_rules: [])
}

fn built_in_rules() -> List(rule.Rule) {
  [
    avoid_panic.rule(),
    avoid_todo.rule(),
    echo_rule.rule(),
    assert_ok_pattern.rule(),
    redundant_case.rule(),
    unwrap_used.rule(),
    panic_without_message.rule(),
    string_inspect.rule(),
    todo_without_message.rule(),
    unnecessary_string_concatenation.rule(),
    error_context_lost.rule(),
    thrown_away_error.rule(),
    missing_type_annotation.rule(),
    function_complexity.rule(),
    label_possible.rule(),
    trailing_underscore.rule(),
    stringly_typed_error.rule(),
    prefer_guard_clause.rule(),
    duplicate_import.rule(),
    unqualified_import.rule(),
    deep_nesting.rule(),
    module_complexity.rule(),
    missing_labels.rule(),
    short_variable_name.rule(),
    unnecessary_variable.rule(),
    discarded_result.rule(),
    division_by_zero.rule(),
  ]
}

fn count_lines(sources: List(#(String, String))) -> Int {
  sources
  |> list.fold(0, fn(acc, s) {
    acc + { string.split(s.1, "\n") |> list.length }
  })
}

/// Parse CLI arguments into (format, config_path, project_prefix, paths).
/// project_prefix is "" when no --project is given, or "dir/" when it is.
fn parse_args(
  args: List(String),
) -> #(reporter.Format, String, Bool, List(String)) {
  let #(format, project_dir, show_stats, paths) =
    parse_args_loop(args, Text, None, False, [])

  let prefix = case project_dir {
    Some(dir) ->
      case string.ends_with(dir, "/") {
        True -> dir
        False -> dir <> "/"
      }
    None -> ""
  }

  let resolved_paths = case paths {
    [] -> []
    _ ->
      list.reverse(paths)
      |> list.map(fn(p) {
        case string.starts_with(p, "/") || prefix == "" {
          True -> p
          False -> prefix <> p
        }
      })
  }

  #(format, prefix, show_stats, resolved_paths)
}

fn parse_args_loop(
  args: List(String),
  format: reporter.Format,
  project_dir: option.Option(String),
  show_stats: Bool,
  paths: List(String),
) -> #(reporter.Format, option.Option(String), Bool, List(String)) {
  case args {
    [] -> #(format, project_dir, show_stats, paths)
    ["--format", "json", ..rest] ->
      parse_args_loop(rest, Json, project_dir, show_stats, paths)
    ["--format", "text", ..rest] ->
      parse_args_loop(rest, Text, project_dir, show_stats, paths)
    ["--project", dir, ..rest] ->
      parse_args_loop(rest, format, Some(dir), show_stats, paths)
    ["--stats", ..rest] ->
      parse_args_loop(rest, format, project_dir, True, paths)
    [path, ..rest] ->
      parse_args_loop(rest, format, project_dir, show_stats, [path, ..paths])
  }
}

fn load_config(path: String) -> config.Config {
  case simplifile.read(path) {
    Error(_) -> config.default()
    Ok(content) ->
      case config.parse(content) {
        Error(_) -> {
          io.println_error(
            "Warning: Could not parse config file, using defaults",
          )
          config.default()
        }
        Ok(cfg) -> cfg
      }
  }
}

fn apply_config(
  rules: List(rule.Rule),
  cfg: config.Config,
) -> List(rule.Rule) {
  rules
  |> list.filter(fn(r) {
    case dict.get(cfg.rules, rule.name(r)) {
      // Explicitly set to off in config
      Ok(None) -> False
      // Explicitly enabled in config
      Ok(_) -> True
      // Not in config: use the rule's default severity
      Error(_) -> rule.default_severity(r) != rule.Off
    }
  })
}

fn discover_files(paths: List(String)) -> List(String) {
  paths
  |> list.flat_map(fn(path) {
    case simplifile.is_directory(path) {
      Ok(True) ->
        case simplifile.get_files(path) {
          Ok(files) ->
            files |> list.filter(fn(f) { string.ends_with(f, ".gleam") })
          Error(_) -> {
            io.println_error("Warning: Could not read directory " <> path)
            []
          }
        }
      _ ->
        case string.ends_with(path, ".gleam") {
          True -> [path]
          False -> []
        }
    }
  })
  |> list.sort(string.compare)
}

/// Strip a prefix from a path, returning the relative portion.
fn strip_prefix(path: String, prefix: String) -> String {
  case prefix {
    "" -> path
    _ ->
      case string.starts_with(path, prefix) {
        True -> string.drop_start(path, string.length(prefix))
        False -> path
      }
  }
}

/// Convert a file path like "src/myapp/users.gleam" to module path "myapp/users"
fn file_path_to_module_path(path: String) -> String {
  path
  |> string.replace(".gleam", "")
  |> string.split("/")
  |> list.drop(1)
  |> string.join("/")
}

/// Run unused exports detection as a cross-module pass.
fn run_unused_exports(
  parsed_files: List(#(String, String, glance.Module)),
  project_prefix: String,
  cfg: config.Config,
) -> List(rule.LintResult) {
  // Check if rule is enabled
  let severity = case dict.get(cfg.rules, "unused_exports") {
    Ok(None) -> Error(Nil)
    Ok(Some(config.SeverityError)) -> Ok(rule.Error)
    Ok(Some(config.SeverityWarning)) -> Ok(rule.Warning)
    Error(_) -> Ok(rule.Warning)
  }

  case severity {
    Error(_) -> []
    Ok(sev) -> {
      // Build src file tuples with module paths from already-parsed files
      let parsed_src =
        parsed_files
        |> list.map(fn(f) {
          let #(file_path, _, module) = f
          #(file_path, file_path_to_module_path(file_path), module)
        })

      // Discover and parse test files as additional consumers
      let test_dir = project_prefix <> "test/"
      let parsed_test = case simplifile.is_directory(test_dir) {
        Ok(True) ->
          discover_files([test_dir])
          |> list.filter_map(fn(abs_path) {
            let rel_path = strip_prefix(abs_path, project_prefix)
            case simplifile.read(abs_path) {
              Ok(source) ->
                case glance.module(source) {
                  Ok(module) ->
                    Ok(#(
                      rel_path,
                      file_path_to_module_path(rel_path),
                      module,
                    ))
                  Error(_) -> Error(Nil)
                }
              Error(_) -> Error(Nil)
            }
          })
        _ -> []
      }

      unused_exports.check_unused_exports(
        parsed_src: parsed_src,
        parsed_test: parsed_test,
        severity: sev,
      )
      |> list.filter(fn(r) {
        !ignore.is_rule_ignored(r.file, "unused_exports", cfg.ignore)
      })
    }
  }
}

/// Run FFI usage detection as a cross-file pass (scans .mjs/.js files).
/// Default severity is Off — must be explicitly enabled in config.
fn run_ffi_usage(
  effective_paths: List(String),
  project_prefix: String,
  cfg: config.Config,
) -> List(rule.LintResult) {
  let severity = case dict.get(cfg.rules, "ffi_usage") {
    Ok(None) -> Error(Nil)
    Ok(Some(config.SeverityError)) -> Ok(rule.Error)
    Ok(Some(config.SeverityWarning)) -> Ok(rule.Warning)
    Error(_) -> Error(Nil)
  }

  case severity {
    Error(_) -> []
    Ok(sev) -> {
      let dirs =
        effective_paths
        |> list.map(fn(p) { strip_prefix(p, project_prefix) })
      ffi_usage.check_ffi_files(dirs, project_prefix)
      |> list.map(fn(r) { rule.LintResult(..r, severity: sev) })
      |> list.filter(fn(r) {
        !ignore.is_rule_ignored(r.file, "ffi_usage", cfg.ignore)
      })
    }
  }
}

@external(erlang, "erlang", "halt")
fn halt(status: Int) -> Nil

@external(erlang, "glinter_ffi", "monotonic_time_ms")
fn monotonic_time_ms() -> Int
