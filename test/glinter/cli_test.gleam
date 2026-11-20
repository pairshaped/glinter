import glance
import gleam/list
import gleam/string
import glinter
import glinter/rule
import simplifile

fn project_dir(name: String) -> String {
  "build/test-cli/" <> name <> "/"
}

fn write_project(name: String, source: String) -> String {
  let dir = project_dir(name)
  let _ = simplifile.delete(file_or_dir_at: dir)
  let assert Ok(Nil) = simplifile.create_directory_all(dir <> "src")
  let assert Ok(Nil) = simplifile.write(to: dir <> "gleam.toml", contents: "")
  let assert Ok(Nil) =
    simplifile.write(to: dir <> "src/app.gleam", contents: source)
  dir
}

fn write_project_with_config(
  name: String,
  config: String,
  source: String,
) -> String {
  let dir = write_project(name, source)
  let assert Ok(Nil) =
    simplifile.write(to: dir <> "gleam.toml", contents: config)
  dir
}

fn make_rule(name: String, target_variable: String) -> rule.Rule {
  rule.new(name: name)
  |> rule.with_simple_expression_visitor(visitor: fn(expression, span) {
    case expression {
      glance.Variable(_, n) if n == target_variable -> [
        rule.error(
          message: "Found " <> target_variable,
          details: "",
          location: span,
        ),
      ]
      _ -> []
    }
  })
  |> rule.to_module_rule()
}

pub fn run_with_args_returns_output_without_halting_for_clean_project_test() {
  let dir = write_project("clean", "pub fn main() -> Int { 1 }")

  let result = glinter.run_with_args(args: ["--project", dir], extra_rules: [])

  let assert 0 = result.exit_code
  let assert True = result.output == "No issues found."
}

pub fn run_with_args_returns_deterministic_stats_test() {
  let dir = write_project("stats", "pub fn main() -> Int { 1 }")

  let result =
    glinter.run_with_args(args: ["--project", dir, "--stats"], extra_rules: [])

  let assert 0 = result.exit_code
  let assert True =
    string.contains(result.output, contain: "Linted 1 file (1 line) in 0ms")
}

pub fn run_with_args_returns_error_exit_code_without_halting_test() {
  let dir = write_project("todo", "pub fn main() -> Int { todo as \"later\" }")

  let result = glinter.run_with_args(args: ["--project", dir], extra_rules: [])

  let assert 1 = result.exit_code
  let assert True =
    string.contains(result.output, contain: "[error] avoid_todo")
}

pub fn run_with_args_honors_warnings_as_errors_test() {
  let dir =
    write_project_with_config(
      "warnings-as-errors",
      "[tools.glinter]
warnings_as_errors = true
",
      "pub fn main() -> Int { echo 1 }",
    )

  let result = glinter.run_with_args(args: ["--project", dir], extra_rules: [])

  let assert 1 = result.exit_code
  let assert True = string.contains(result.output, contain: "[error] echo")
}

pub fn run_with_args_honors_module_rule_severity_test() {
  let severity_cases = [
    #(
      "module-severity-unwrap-error",
      "unwrap_used",
      "error",
      "import gleam/result\npub fn main() -> Int { result.unwrap(Ok(1), 0) }",
      1,
    ),
    #(
      "module-severity-echo-error",
      "echo",
      "error",
      "pub fn main() -> Int { echo 1 }",
      1,
    ),
    #(
      "module-severity-todo-warning",
      "avoid_todo",
      "warning",
      "pub fn main() -> Int { todo as \"later\" }",
      0,
    ),
  ]

  list.each(severity_cases, fn(severity_case) {
    let #(
      project_name,
      rule_name,
      configured_severity,
      source_text,
      expected_exit_code,
    ) = severity_case
    let dir =
      write_project_with_config(
        project_name,
        "[tools.glinter.rules]\n"
          <> rule_name
          <> " = \""
          <> configured_severity
          <> "\"\n",
        source_text,
      )

    let run_result =
      glinter.run_with_args(args: ["--project", dir], extra_rules: [])

    let assert #(True, True) = #(
      run_result.exit_code == expected_exit_code,
      string.contains(
        run_result.output,
        contain: "[" <> configured_severity <> "] " <> rule_name,
      ),
    )
  })
}

pub fn run_with_args_honors_project_rule_severity_test() {
  let severity_cases = [
    #("project-severity-off-error", rule.Off, "error", 1),
    #("project-severity-warning-error", rule.Warning, "error", 1),
    #("project-severity-error-warning", rule.Error, "warning", 0),
  ]

  list.each(severity_cases, fn(severity_case) {
    let #(
      project_name,
      default_severity,
      configured_severity,
      expected_exit_code,
    ) = severity_case
    let project_rule =
      rule.new_project(name: "project_severity", initial: Nil)
      |> rule.with_project_default_severity(severity: default_severity)
      |> rule.with_final_project_evaluation(evaluator: fn(_project_context) {
        [
          #(
            "src/app.gleam",
            rule.error(
              message: "Project severity finding",
              details: "",
              location: glance.Span(start: 0, end: 0),
            ),
          ),
        ]
      })
      |> rule.to_project_rule()
    let dir =
      write_project_with_config(
        project_name,
        "[tools.glinter.rules]\nproject_severity = \""
          <> configured_severity
          <> "\"\n",
        "pub fn main() -> Int { 1 }",
      )

    let run_result =
      glinter.run_with_args(args: ["--project", dir], extra_rules: [
        project_rule,
      ])

    let assert #(True, True) = #(
      run_result.exit_code == expected_exit_code,
      string.contains(
        run_result.output,
        contain: "[" <> configured_severity <> "] project_severity",
      ),
    )
  })
}

pub fn run_with_args_honors_include_config_test() {
  let dir =
    write_project_with_config(
      "include",
      "[tools.glinter]
include = [\"test/\"]
",
      "pub fn main() -> Int { 1 }",
    )
  let assert Ok(Nil) = simplifile.create_directory_all(dir <> "test")
  let assert Ok(Nil) =
    simplifile.write(
      to: dir <> "test/app_test.gleam",
      contents: "pub fn main() -> Int { todo as \"later\" }",
    )

  let result = glinter.run_with_args(args: ["--project", dir], extra_rules: [])

  let assert 1 = result.exit_code
  let assert True =
    string.contains(result.output, contain: "test/app_test.gleam:1:")
}

pub fn run_with_args_honors_exclude_config_test() {
  let dir =
    write_project_with_config(
      "exclude",
      "[tools.glinter]
include = [\"src/\", \"test/\"]
exclude = [\"test/\"]
",
      "pub fn main() -> Int { 1 }",
    )
  let assert Ok(Nil) = simplifile.create_directory_all(dir <> "test")
  let assert Ok(Nil) =
    simplifile.write(
      to: dir <> "test/app_test.gleam",
      contents: "pub fn main() -> Int { todo as \"later\" }",
    )

  let result = glinter.run_with_args(args: ["--project", dir], extra_rules: [])

  let assert 0 = result.exit_code
  let assert True = result.output == "No issues found."
}

pub fn run_with_args_supports_json_format_test() {
  let dir = write_project("json", "pub fn main() -> Int { todo as \"later\" }")

  let result =
    glinter.run_with_args(
      args: ["--project", dir, "--format", "json"],
      extra_rules: [],
    )

  let assert 1 = result.exit_code
  let assert True = string.contains(result.output, contain: "\"errors\":1")
  let assert True = string.contains(result.output, contain: "\"line\":1")
  let assert True =
    string.contains(result.output, contain: "\"file\":\"src/app.gleam\"")
}

pub fn run_with_args_runs_extra_rules_test() {
  let dir = write_project("extra-rules", "pub fn main() -> Int { flagged }")

  let result =
    glinter.run_with_args(args: ["--project", dir], extra_rules: [
      make_rule("custom_flag", "flagged"),
    ])

  let assert 0 = result.exit_code
  let assert True =
    string.contains(result.output, contain: "[warning] custom_flag")
}
