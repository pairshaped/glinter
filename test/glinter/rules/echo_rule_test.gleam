import gleam/list
import glinter/rule
import glinter/rules/echo_rule
import glinter/test_helpers

pub fn detects_echo_test() {
  let results =
    test_helpers.lint_string_rule(
      "pub fn debug() { echo 42 }",
      echo_rule.rule(),
    )
  let assert True = list.length(results) == 1
  let assert [result] = results
  let assert True = result.rule == "echo"
  let assert True = result.severity == rule.Warning
}

pub fn ignores_clean_code_test() {
  let results =
    test_helpers.lint_string_rule("pub fn good() { 42 }", echo_rule.rule())
  let assert True = results == []
}
