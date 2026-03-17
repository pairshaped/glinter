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
import glinter/rule.{type V2Rule, V2Rule}
import glinter/rules/assert_ok_pattern
import glinter/rules/avoid_panic
import glinter/rules/avoid_todo
import glinter/rules/deep_nesting
import glinter/rules/discarded_result
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
import glinter/walker
import simplifile

pub fn main() {
  let start_time = monotonic_time_ms()
  let args = argv.load().arguments
  let #(format, project_prefix, show_stats, paths) = parse_args(args)

  let config_path = project_prefix <> "gleam.toml"
  let cfg = load_config(config_path)
  let show_stats = show_stats || cfg.stats

  let all_rules = [
    avoid_panic.rule(),
    avoid_todo.rule(),
    echo_rule.rule(),
    assert_ok_pattern.rule(),
    discarded_result.rule(),
    short_variable_name.rule(),
    unnecessary_variable.rule(),
    redundant_case.rule(),
    unwrap_used.rule(),
    deep_nesting.rule(),
    function_complexity.rule(),
    module_complexity.rule(),
    prefer_guard_clause.rule(),
    label_possible.rule(),
    missing_labels.rule(),
    missing_type_annotation.rule(),
    panic_without_message.rule(),
    string_inspect.rule(),
    duplicate_import.rule(),
    todo_without_message.rule(),
    unqualified_import.rule(),
    unnecessary_string_concatenation.rule(),
    trailing_underscore.rule(),
    error_context_lost.rule(),
    stringly_typed_error.rule(),
    thrown_away_error.rule(),
  ]
  let rules = apply_config(all_rules, cfg)

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

  // Convert V2 rules to new Rule type and run through the runner
  let new_rules =
    list.map(rules, fn(r) {
      rule.from_v2_rule(v2: r, module_data_builder: build_module_data)
    })
  let per_file_results =
    runner.run(rules: new_rules, files: parsed_files, config: cfg)

  // Cross-module: unused exports detection (special-cased until ported)
  let unused_export_results = run_unused_exports(sources, project_prefix, cfg)
  let results = list.append(per_file_results, unused_export_results)

  // Cross-file: FFI usage detection (special-cased until ported)
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

fn apply_config(rules: List(V2Rule), cfg: config.Config) -> List(V2Rule) {
  rules
  |> list.filter_map(fn(r) {
    // Apply config override, or keep default
    let resolved = case dict.get(cfg.rules, r.name) {
      Ok(None) -> V2Rule(..r, default_severity: rule.Off)
      Ok(Some(config.SeverityError)) ->
        V2Rule(..r, default_severity: rule.Error)
      Ok(Some(config.SeverityWarning)) ->
        V2Rule(..r, default_severity: rule.Warning)
      Error(_) -> r
    }
    // Filter out Off rules
    case resolved.default_severity {
      rule.Off -> Error(Nil)
      _ -> Ok(resolved)
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
  sources: List(#(String, String)),
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
      // Build src file tuples: #(display_path, module_path, source)
      let src_files =
        sources
        |> list.map(fn(s) {
          let #(file_path, source) = s
          #(file_path, file_path_to_module_path(file_path), source)
        })

      // Discover test files as additional consumers
      let test_dir = project_prefix <> "test/"
      let test_files = case simplifile.is_directory(test_dir) {
        Ok(True) ->
          discover_files([test_dir])
          |> list.filter_map(fn(abs_path) {
            let rel_path = strip_prefix(abs_path, project_prefix)
            case simplifile.read(abs_path) {
              Ok(source) ->
                Ok(#(rel_path, file_path_to_module_path(rel_path), source))
              Error(_) -> Error(Nil)
            }
          })
        _ -> []
      }

      unused_exports.check_unused_exports(src_files, test_files, sev)
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

/// Build ModuleData from a parsed module, using walker when needs_collect is True.
/// Passed to rule.from_v2_rule to avoid an import cycle between rule and walker.
fn build_module_data(
  module: glance.Module,
  needs_collect: Bool,
) -> rule.ModuleData {
  case needs_collect {
    True -> walker.collect(module)
    False -> walker.module_only(module)
  }
}

@external(erlang, "erlang", "halt")
fn halt(status: Int) -> Nil

@external(erlang, "glinter_ffi", "monotonic_time_ms")
fn monotonic_time_ms() -> Int
