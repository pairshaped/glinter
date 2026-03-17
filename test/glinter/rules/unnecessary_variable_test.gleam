import gleam/list
import glinter/rule
import glinter/rules/unnecessary_variable
import glinter/test_helpers

pub fn detects_trailing_let_in_function_test() {
  let results =
    test_helpers.lint_string_rule(
      "pub fn bad() { let x = 1 \n x }",
      unnecessary_variable.rule(),
    )
  let assert True = list.length(results) == 1
  let assert [result] = results
  let assert True = result.rule == "unnecessary_variable"
  let assert True = result.severity == rule.Warning
}

pub fn ignores_different_names_test() {
  let results =
    test_helpers.lint_string_rule(
      "pub fn ok() { let x = 1 \n y }",
      unnecessary_variable.rule(),
    )
  let assert True = results == []
}

pub fn ignores_statements_between_test() {
  let results =
    test_helpers.lint_string_rule(
      "pub fn ok() { let x = 1 \n do_something() \n x }",
      unnecessary_variable.rule(),
    )
  let assert True = results == []
}

pub fn detects_in_block_test() {
  let results =
    test_helpers.lint_string_rule(
      "pub fn bad() { { let x = 1 \n x } }",
      unnecessary_variable.rule(),
    )
  let assert True = list.length(results) == 1
}

pub fn detects_in_case_branch_test() {
  let results =
    test_helpers.lint_string_rule(
      "pub fn bad(v) { case v { _ -> { let x = 1 \n x } } }",
      unnecessary_variable.rule(),
    )
  let assert True = list.length(results) == 1
}

pub fn detects_in_anonymous_fn_test() {
  let results =
    test_helpers.lint_string_rule(
      "pub fn bad() { fn() { let x = 1 \n x } }",
      unnecessary_variable.rule(),
    )
  let assert True = list.length(results) == 1
}

pub fn ignores_pattern_match_assignment_test() {
  let results =
    test_helpers.lint_string_rule(
      "pub fn ok() { let #(a, _) = get() \n a }",
      unnecessary_variable.rule(),
    )
  let assert True = results == []
}
