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
import glinter/walker
import simplifile

pub fn main() {
  let args = argv.load().arguments
  let #(format, config_path, paths) = parse_args(args)

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
  ]
  let rules = apply_config(all_rules, cfg)

  let files = discover_files(paths)

  let #(rev_results, rev_sources) =
    files
    |> list.fold(#([], []), fn(acc, file_path) {
      let #(acc_results, acc_sources) = acc
      case lint_file(file_path, rules, cfg) {
        Ok(#(file_results, source)) ->
          #(
            list.append(list.reverse(file_results), acc_results),
            [#(file_path, source), ..acc_sources],
          )
        Error(_) -> acc
      }
    })
  let results = list.reverse(rev_results)
  let sources = list.reverse(rev_sources)

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

fn parse_args(
  args: List(String),
) -> #(reporter.Format, String, List(String)) {
  parse_args_loop(args, Text, "gleam_lint.toml", [])
}

fn parse_args_loop(
  args: List(String),
  format: reporter.Format,
  config_path: String,
  paths: List(String),
) -> #(reporter.Format, String, List(String)) {
  case args {
    [] -> {
      let final_paths = case paths {
        [] -> ["src/"]
        _ -> list.reverse(paths)
      }
      #(format, config_path, final_paths)
    }
    ["--format", "json", ..rest] ->
      parse_args_loop(rest, Json, config_path, paths)
    ["--format", "text", ..rest] ->
      parse_args_loop(rest, Text, config_path, paths)
    ["--config", path, ..rest] ->
      parse_args_loop(rest, format, path, paths)
    [path, ..rest] ->
      parse_args_loop(rest, format, config_path, [path, ..paths])
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

fn lint_file(
  file_path: String,
  rules: List(Rule),
  cfg: config.Config,
) -> Result(#(List(rule.LintResult), String), Nil) {
  case simplifile.read(file_path) {
    Error(_) -> {
      io.println_error("Error: Could not read " <> file_path)
      Error(Nil)
    }
    Ok(source) -> {
      let active_rules =
        rules
        |> list.filter(fn(r) {
          !ignore.is_rule_ignored(file_path, r.name, cfg.ignore)
        })
      case glance.module(source) {
        Error(_) -> {
          io.println_error("Error: Failed to parse " <> file_path)
          Error(Nil)
        }
        Ok(module) -> {
          let file_results =
            walker.walk_module(module, active_rules, source, file_path)
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

@external(erlang, "erlang", "halt")
fn halt(status: Int) -> Nil
