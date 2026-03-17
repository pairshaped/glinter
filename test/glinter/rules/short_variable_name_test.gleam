import gleam/list
import glinter/rule
import glinter/rules/short_variable_name
import glinter/test_helpers

pub fn detects_single_letter_name_test() {
  let results =
    test_helpers.lint_string_rule(
      "pub fn bad() { let x = 1 \n x }",
      short_variable_name.rule(),
    )
  let assert True = list.length(results) == 1
  let assert [result] = results
  let assert True = result.rule == "short_variable_name"
  let assert True = result.severity == rule.Warning
}

pub fn ignores_descriptive_name_test() {
  let results =
    test_helpers.lint_string_rule(
      "pub fn ok() { let count = 1 \n count }",
      short_variable_name.rule(),
    )
  let assert True = results == []
}

pub fn ignores_single_letter_fn_param_test() {
  let results =
    test_helpers.lint_string_rule(
      "import gleam/list
pub fn ok() { list.map([1], fn(x) { x }) }",
      short_variable_name.rule(),
    )
  let assert True = results == []
}

pub fn ignores_case_clause_pattern_test() {
  let results =
    test_helpers.lint_string_rule(
      "pub fn ok(val) { case val { x -> x } }",
      short_variable_name.rule(),
    )
  let assert True = results == []
}

pub fn detects_multiple_short_names_test() {
  let results =
    test_helpers.lint_string_rule(
      "pub fn bad() { let a = 1 \n let b = 2 \n a + b }",
      short_variable_name.rule(),
    )
  let assert True = list.length(results) == 2
}
