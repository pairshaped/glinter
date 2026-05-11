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
import glinter/annotation
import glinter/source
import glinter/unused_exports
import simplifile

pub type RunResult {
  RunResult(output: String, exit_code: Int)
}

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
  let result =
    run_with_args_and_clock(
      args: args,
      extra_rules: extra_rules,
      start_time: start_time,
      now: monotonic_time_ms,
    )
  io.println(result.output)
  halt(result.exit_code)
}

/// Run glinter for a set of CLI arguments, returning output and exit code
/// without printing or halting.
pub fn run_with_args(
  args args: List(String),
  extra_rules extra_rules: List(rule.Rule),
) -> RunResult {
  run_with_args_and_clock(
    args: args,
    extra_rules: extra_rules,
    start_time: 0,
    now: fn() { 0 },
  )
}

fn run_with_args_and_clock(
  args args: List(String),
  extra_rules extra_rules: List(rule.Rule),
  start_time start_time: Int,
  now now: fn() -> Int,
) -> RunResult {
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

  // Scan-only paths: parsed for cross-module analysis (e.g. usage detection),
  // never reported on. Used to teach glinter about callers in generated client
  // packages that live outside the linted source tree.
  let scan_only_paths =
    list.map(cfg.scan_paths, fn(p) { project_prefix <> p })

  // Discover files (absolute paths), then make relative for ignore matching
  // and cleaner output
  let file_paths =
    discover_files(effective_paths)
    |> list.map(fn(f) { source.strip_prefix(f, project_prefix) })
    |> list.filter(fn(f) { !ignore.is_file_excluded(f, cfg.exclude) })

  let scan_only_file_paths =
    discover_files(scan_only_paths)
    |> list.map(fn(f) { source.strip_prefix(f, project_prefix) })

  let parse_file = fn(
    acc: #(List(#(String, String, glance.Module)), List(#(String, String))),
    file_path: String,
  ) {
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
  }

  // Read and parse lintable files
  let #(parsed_files, sources) =
    file_paths
    |> list.fold(#([], []), parse_file)
  let parsed_files = list.reverse(parsed_files)
  let sources = list.reverse(sources)

  // Read and parse scan-only files (for cross-module usage detection)
  let #(scan_only_parsed, _) =
    scan_only_file_paths
    |> list.fold(#([], []), parse_file)
  let scan_only_parsed = list.reverse(scan_only_parsed)

  let all_rules = apply_config(module_rules, cfg)
  let per_file_results =
    runner.run(rules: all_rules, files: parsed_files, config: cfg)

  // Cross-module: unused exports detection (special-cased — needs file paths
  // and src/test distinction that the project rule API doesn't yet provide).
  // Scan-only modules participate as consumers so their imports are visible,
  // but no results are reported on them.
  let unfiltered_unused_export_results =
    run_unused_exports(parsed_files, scan_only_parsed, project_prefix, cfg)
  let unused_export_results =
    apply_nolint_filter(unfiltered_unused_export_results, parsed_files)
  // The per-file runner emits nolint_unused for annotations targeting
  // cross-file rules (like unused_exports) because it doesn't see those
  // results. Reconcile by removing nolint_unused warnings whose annotations
  // actually suppressed a cross-file result.
  let per_file_results =
    reconcile_cross_file_nolint(
      per_file_results,
      unfiltered_unused_export_results,
      parsed_files,
    )
  let results = list.append(per_file_results, unused_export_results)

  // Cross-file: FFI usage detection (special-cased — scans .mjs files,
  // not Gleam AST). Returns results and .mjs source texts needed by the
  // reporter to translate byte offsets back to line numbers.
  let #(ffi_results, ffi_sources) =
    run_ffi_usage(effective_paths, project_prefix, cfg)
  let results = list.append(results, ffi_results)
  let sources = list.append(sources, ffi_sources)

  // Promote warnings to errors if configured
  let results = case cfg.warnings_as_errors {
    True ->
      list.map(results, fn(r) {
        case r.severity {
          rule.Warning -> rule.LintResult(..r, severity: rule.Error)
          _ -> r
        }
      })
    False -> results
  }

  let elapsed_ms = now() - start_time
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

  let has_errors = list.any(results, fn(r) { r.severity == rule.Error })
  let exit_code = case has_errors {
    True -> 1
    False -> 0
  }
  RunResult(output: output, exit_code: exit_code)
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

fn apply_config(rules: List(rule.Rule), cfg: config.Config) -> List(rule.Rule) {
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

/// Convert a file path like "src/myapp/users.gleam" to module path "myapp/users"
fn file_path_to_module_path(path: String) -> String {
  path
  |> string.replace(".gleam", "")
  |> string.split("/")
  |> list.drop(1)
  |> string.join("/")
}

/// Apply nolint annotation filtering to cross-module results.
/// Groups results by file, looks up the source/module for each, and filters.
fn apply_nolint_filter(
  results: List(rule.LintResult),
  parsed_files: List(#(String, String, glance.Module)),
) -> List(rule.LintResult) {
  results
  |> list.filter(fn(r) {
    case list.find(parsed_files, fn(f) { f.0 == r.file }) {
      Ok(#(_, source_text, module)) ->
        // Keep only if NOT filtered by annotations
        runner.filter_annotations([r], source_text, module) != []
      Error(_) -> True
    }
  })
}

/// Remove false nolint_unused warnings for annotations that suppressed
/// cross-file results. The per-file runner can't see cross-file results when
/// it emits nolint_unused, so we reconcile after the fact.
fn reconcile_cross_file_nolint(
  per_file_results: List(rule.LintResult),
  cross_file_results: List(rule.LintResult),
  parsed_files: List(#(String, String, glance.Module)),
) -> List(rule.LintResult) {
  list.filter(per_file_results, fn(r) {
    case r.rule == "nolint_unused" {
      False -> True
      True ->
        case list.find(parsed_files, fn(f) { f.0 == r.file }) {
          Error(_) -> True
          Ok(#(_, source_text, module)) -> {
            let cross_file_for_file =
              list.filter(cross_file_results, fn(cf) { cf.file == r.file })
            !annotation_at_location_suppresses_any(
              source_text,
              module,
              r.location,
              cross_file_for_file,
            )
          }
        }
    }
  })
}

/// Check if the nolint annotation at the given location would suppress any of
/// the provided results. Uses the same scope rules as the runner: line-scope
/// annotations match the next line, function-scope annotations match any line
/// within the function body.
fn annotation_at_location_suppresses_any(
  source_text: String,
  module: glance.Module,
  nolint_location: glance.Span,
  results: List(rule.LintResult),
) -> Bool {
  let annotations = annotation.parse(source_text)
  let nolint_line =
    source.byte_offset_to_line(source_text, nolint_location.start)
  case list.find(annotations, fn(ann) { ann.comment_line == nolint_line }) {
    Error(_) -> False
    Ok(ann) -> {
      let function_ranges =
        module.functions
        |> list.map(fn(func_def) {
          let span = func_def.definition.location
          #(
            source.byte_offset_to_line(source_text, span.start),
            source.byte_offset_to_line(source_text, span.end),
          )
        })
      list.any(results, fn(result) {
        let error_line =
          source.byte_offset_to_line(source_text, result.location.start)
        let rule_matches = list.contains(ann.rules, result.rule)
        let line_matches = case ann.scope {
          annotation.LineScope -> ann.target_line == error_line
          annotation.FunctionScope ->
            list.any(function_ranges, fn(range) {
              range.0 == ann.target_line
              && error_line >= range.0
              && error_line <= range.1
            })
          annotation.Stale -> False
        }
        rule_matches && line_matches
      })
    }
  }
}

/// Run unused exports detection as a cross-module pass.
fn run_unused_exports(
  parsed_files: List(#(String, String, glance.Module)),
  parsed_extra_consumers: List(#(String, String, glance.Module)),
  project_prefix: String,
  cfg: config.Config,
) -> List(rule.LintResult) {
  let severity =
    config.resolve_severity(cfg, "unused_exports", fn() { Ok(rule.Warning) })

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
            let rel_path = source.strip_prefix(abs_path, project_prefix)
            case simplifile.read(abs_path) {
              Ok(source) ->
                case glance.module(source) {
                  Ok(module) ->
                    Ok(#(rel_path, file_path_to_module_path(rel_path), module))
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
        parsed_extra_consumers: parsed_extra_consumers,
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
) -> #(List(rule.LintResult), List(#(String, String))) {
  let severity = config.resolve_severity(cfg, "ffi_usage", fn() { Error(Nil) })

  case severity {
    Error(_) -> #([], [])
    Ok(sev) -> {
      let dirs =
        effective_paths
        |> list.map(fn(p) { source.strip_prefix(p, project_prefix) })
      let #(raw_results, raw_sources) =
        ffi_usage.check_ffi_files(dirs, project_prefix)
      let results =
        raw_results
        |> list.map(fn(r) { rule.LintResult(..r, severity: sev) })
        |> list.filter(fn(r) {
          !ignore.is_rule_ignored(r.file, "ffi_usage", cfg.ignore)
        })
      #(results, raw_sources)
    }
  }
}

@external(erlang, "erlang", "halt")
fn halt(status: Int) -> Nil

@external(erlang, "glinter_ffi", "monotonic_time_ms")
fn monotonic_time_ms() -> Int
