import gleam/list
import glinter/rule
import glinter/rules/assert_ok_pattern
import glinter/test_helpers

pub fn detects_let_assert_test() {
  let results =
    test_helpers.lint_string_rule(
      "pub fn bad() { let assert Ok(x) = get() \n x }",
      assert_ok_pattern.rule(),
    )
  let assert True = list.length(results) == 1
  let assert [result] = results
  let assert True = result.rule == "assert_ok_pattern"
  let assert True = result.severity == rule.Warning
}

pub fn ignores_regular_let_test() {
  let results =
    test_helpers.lint_string_rule(
      "pub fn good() { let x = 1 \n x }",
      assert_ok_pattern.rule(),
    )
  let assert True = results == []
}

pub fn ignores_case_pattern_match_test() {
  let results =
    test_helpers.lint_string_rule(
      "pub fn good(x) { case x { Ok(v) -> v \n _ -> 0 } }",
      assert_ok_pattern.rule(),
    )
  let assert True = results == []
}
