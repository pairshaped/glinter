import gleam/list
import glinter/rule
import glinter/rules/unnecessary_string_concatenation
import glinter/test_helpers

pub fn detects_concat_with_empty_right_test() {
  let results =
    test_helpers.lint_string_rule(
      "pub fn bad(x) { x <> \"\" }",
      unnecessary_string_concatenation.rule(),
    )
  let assert True = list.length(results) == 1
  let assert [result] = results
  let assert True = result.rule == "unnecessary_string_concatenation"
  let assert True = result.severity == rule.Warning
}

pub fn detects_concat_with_empty_left_test() {
  let results =
    test_helpers.lint_string_rule(
      "pub fn bad(x) { \"\" <> x }",
      unnecessary_string_concatenation.rule(),
    )
  let assert True = list.length(results) == 1
}

pub fn detects_two_literal_concat_test() {
  let results =
    test_helpers.lint_string_rule(
      "pub fn bad() { \"foo\" <> \"bar\" }",
      unnecessary_string_concatenation.rule(),
    )
  let assert True = list.length(results) == 1
  let assert [result] = results
  let assert True = result.rule == "unnecessary_string_concatenation"
}

pub fn ignores_normal_concat_test() {
  let results =
    test_helpers.lint_string_rule(
      "pub fn ok(x, y) { x <> y }",
      unnecessary_string_concatenation.rule(),
    )
  let assert True = results == []
}

pub fn ignores_concat_with_nonempty_literal_test() {
  let results =
    test_helpers.lint_string_rule(
      "pub fn ok(x) { x <> \" suffix\" }",
      unnecessary_string_concatenation.rule(),
    )
  let assert True = results == []
}
