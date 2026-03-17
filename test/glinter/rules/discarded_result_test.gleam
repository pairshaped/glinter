import gleam/list
import glinter/rule
import glinter/rules/discarded_result
import glinter/test_helpers

pub fn detects_discarded_result_test() {
  let results =
    test_helpers.lint_string_rule(
      "pub fn bad() { let _ = get() \n 1 }",
      discarded_result.rule(),
    )
  let assert True = list.length(results) == 1
  let assert [result] = results
  let assert True = result.rule == "discarded_result"
  let assert True = result.severity == rule.Warning
}

pub fn ignores_named_discard_test() {
  let results =
    test_helpers.lint_string_rule(
      "pub fn ok() { let _result = get() \n 1 }",
      discarded_result.rule(),
    )
  let assert True = results == []
}

pub fn ignores_regular_assignment_test() {
  let results =
    test_helpers.lint_string_rule(
      "pub fn ok() { let x = 1 \n x }",
      discarded_result.rule(),
    )
  let assert True = results == []
}

pub fn ignores_let_assert_test() {
  let results =
    test_helpers.lint_string_rule(
      "pub fn ok() { let assert Ok(x) = get() \n x }",
      discarded_result.rule(),
    )
  let assert True = results == []
}
