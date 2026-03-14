import argv
import glance
import gleam/dict
import gleam/io
import gleam/list
import gleam/option.{None, Some}
import gleam/string
import glinter/config
import glinter/ignore
import glinter/reporter.{Json, Text}
import glinter/rule.{type Rule}
import glinter/rules/assert_ok_pattern
import glinter/rules/avoid_panic
import glinter/rules/avoid_todo
import glinter/rules/deep_nesting
import glinter/rules/discarded_result
import glinter/rules/echo_rule
import glinter/rules/function_complexity
import glinter/rules/module_complexity
import glinter/rules/prefer_guard_clause
import glinter/rules/redundant_case
import glinter/rules/short_variable_name
import glinter/rules/unnecessary_variable
import glinter/rules/unwrap_used
import glinter/rules/label_possible
import glinter/rules/missing_labels
import glinter/unused_exports
import glinter/walker
import simplifile

pub fn main() {
  let args = argv.load().arguments
  let #(format, config_path, project_prefix, paths) = parse_args(args)

  let cfg = load_config(config_path)

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
  ]
  let rules = apply_config(all_rules, cfg)

  // Discover files (absolute paths), then make relative for ignore matching
  // and cleaner output
  let files =
    discover_files(paths)
    |> list.map(fn(f) { strip_prefix(f, project_prefix) })

  let #(rev_results, rev_sources) =
    files
    |> list.fold(#([], []), fn(acc, file_path) {
      let #(acc_results, acc_sources) = acc
      // Read from the absolute path, but use relative path for reporting
      let read_path = project_prefix <> file_path
      case lint_file(read_path, file_path, rules, cfg) {
        Ok(#(file_results, source)) ->
          #(
            list.append(list.reverse(file_results), acc_results),
            [#(file_path, source), ..acc_sources],
          )
        Error(_) -> acc
      }
    })
  let per_file_results = list.reverse(rev_results)
  let sources = list.reverse(rev_sources)

  // Cross-module: unused exports detection
  let unused_export_results =
    run_unused_exports(sources, project_prefix, cfg)
  let results = list.append(per_file_results, unused_export_results)

  let output = case format {
    Text -> reporter.format_text(results, sources)
    Json -> reporter.format_json(results, sources)
  }
  io.println(output)

  let has_issues = !list.is_empty(results)
  case has_issues {
    True -> halt(1)
    False -> halt(0)
  }
}

/// Parse CLI arguments into (format, config_path, project_prefix, paths).
/// project_prefix is "" when no --project is given, or "dir/" when it is.
fn parse_args(
  args: List(String),
) -> #(reporter.Format, String, String, List(String)) {
  let #(format, config_path, project_dir, paths) =
    parse_args_loop(args, Text, "glinter.toml", None, [])

  case project_dir {
    Some(dir) -> {
      let prefix = case string.ends_with(dir, "/") {
        True -> dir
        False -> dir <> "/"
      }
      let resolved_config = case config_path {
        "glinter.toml" -> prefix <> "glinter.toml"
        other -> other
      }
      let resolved_paths = case paths {
        [] -> [prefix <> "src/"]
        _ ->
          list.reverse(paths)
          |> list.map(fn(p) {
            case string.starts_with(p, "/") {
              True -> p
              False -> prefix <> p
            }
          })
      }
      #(format, resolved_config, prefix, resolved_paths)
    }
    None -> {
      let resolved_paths = case paths {
        [] -> ["src/"]
        _ -> list.reverse(paths)
      }
      #(format, config_path, "", resolved_paths)
    }
  }
}

fn parse_args_loop(
  args: List(String),
  format: reporter.Format,
  config_path: String,
  project_dir: option.Option(String),
  paths: List(String),
) -> #(reporter.Format, String, option.Option(String), List(String)) {
  case args {
    [] -> #(format, config_path, project_dir, paths)
    ["--format", "json", ..rest] ->
      parse_args_loop(rest, Json, config_path, project_dir, paths)
    ["--format", "text", ..rest] ->
      parse_args_loop(rest, Text, config_path, project_dir, paths)
    ["--config", path, ..rest] ->
      parse_args_loop(rest, format, path, project_dir, paths)
    ["--project", dir, ..rest] ->
      parse_args_loop(rest, format, config_path, Some(dir), paths)
    [path, ..rest] ->
      parse_args_loop(rest, format, config_path, project_dir, [path, ..paths])
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

/// Lint a file. Reads from read_path (absolute), reports as display_path (relative).
fn lint_file(
  read_path: String,
  display_path: String,
  rules: List(Rule),
  cfg: config.Config,
) -> Result(#(List(rule.LintResult), String), Nil) {
  case simplifile.read(read_path) {
    Error(_) -> {
      io.println_error("Error: Could not read " <> read_path)
      Error(Nil)
    }
    Ok(source) -> {
      let active_rules =
        rules
        |> list.filter(fn(r) {
          !ignore.is_rule_ignored(display_path, r.name, cfg.ignore)
        })
      case glance.module(source) {
        Error(_) -> {
          io.println_error("Error: Failed to parse " <> read_path)
          Error(Nil)
        }
        Ok(module) -> {
          let file_results =
            walker.walk_module(module, active_rules, source, display_path)
          Ok(#(file_results, source))
        }
      }
    }
  }
}

fn apply_config(rules: List(Rule), cfg: config.Config) -> List(Rule) {
  rules
  |> list.filter_map(fn(r) {
    case dict.get(cfg.rules, r.name) {
      Ok(None) -> Error(Nil)
      Ok(Some(config.SeverityError)) ->
        Ok(rule.Rule(..r, default_severity: rule.Error))
      Ok(Some(config.SeverityWarning)) ->
        Ok(rule.Rule(..r, default_severity: rule.Warning))
      Error(_) -> Ok(r)
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
                Ok(#(
                  rel_path,
                  file_path_to_module_path(rel_path),
                  source,
                ))
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

@external(erlang, "erlang", "halt")
fn halt(status: Int) -> Nil
