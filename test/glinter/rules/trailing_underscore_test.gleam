import gleam/list
import glinter/rule
import glinter/rules/trailing_underscore
import glinter/test_helpers

pub fn detects_trailing_underscore_test() {
  let results =
    test_helpers.lint_string("pub fn bad_() { 1 }", trailing_underscore.rule())
  let assert True = list.length(results) == 1
  let assert [result] = results
  let assert True = result.rule == "trailing_underscore"
  let assert True = result.severity == rule.Warning
}

pub fn detects_trailing_underscore_with_params_test() {
  let results =
    test_helpers.lint_string(
      "pub fn also_bad_(x: Int) { x }",
      trailing_underscore.rule(),
    )
  let assert True = list.length(results) == 1
}

pub fn ignores_normal_function_name_test() {
  let results =
    test_helpers.lint_string(
      "pub fn good_name() { 1 }",
      trailing_underscore.rule(),
    )
  let assert True = results == []
}

pub fn ignores_underscore_in_middle_test() {
  let results =
    test_helpers.lint_string(
      "pub fn has_underscore() { 1 }",
      trailing_underscore.rule(),
    )
  let assert True = results == []
}
