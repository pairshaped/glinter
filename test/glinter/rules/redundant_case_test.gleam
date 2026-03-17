import gleam/list
import glinter/rule
import glinter/rules/redundant_case
import glinter/test_helpers

pub fn detects_single_branch_case_test() {
  let results =
    test_helpers.lint_string_rule(
      "pub fn bad(x) { case x { Ok(v) -> v } }",
      redundant_case.rule(),
    )
  let assert True = list.length(results) == 1
  let assert [result] = results
  let assert True = result.rule == "redundant_case"
  let assert True = result.severity == rule.Warning
}

pub fn ignores_multi_branch_case_test() {
  let results =
    test_helpers.lint_string_rule(
      "pub fn ok(x) { case x { Ok(v) -> v \n Error(_) -> 0 } }",
      redundant_case.rule(),
    )
  let assert True = results == []
}

pub fn ignores_single_branch_with_guard_test() {
  let results =
    test_helpers.lint_string_rule(
      "pub fn ok(x) { case x { v if v > 0 -> v \n _ -> 0 } }",
      redundant_case.rule(),
    )
  let assert True = results == []
}
