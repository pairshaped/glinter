import gleam/list
import glinter/rule
import glinter/rules/thrown_away_error
import glinter/test_helpers

pub fn detects_discarded_error_test() {
  let results =
    test_helpers.lint_string(
      "pub fn bad(r) { case r { Ok(v) -> v \n Error(_) -> 0 } }",
      thrown_away_error.rule(),
    )
  let assert True = list.length(results) == 1
  let assert [result] = results
  let assert True = result.rule == "thrown_away_error"
  let assert True = result.severity == rule.Warning
}

pub fn ignores_named_error_test() {
  let results =
    test_helpers.lint_string(
      "pub fn ok(r) { case r { Ok(v) -> v \n Error(e) -> handle(e) } }",
      thrown_away_error.rule(),
    )
  let assert True = results == []
}

pub fn ignores_non_error_discard_test() {
  let results =
    test_helpers.lint_string(
      "pub fn ok(r) { case r { Ok(_) -> 1 \n Error(e) -> handle(e) } }",
      thrown_away_error.rule(),
    )
  let assert True = results == []
}

pub fn detects_named_discard_error_test() {
  let results =
    test_helpers.lint_string(
      "pub fn bad(r) { case r { Ok(v) -> v \n Error(_err) -> 0 } }",
      thrown_away_error.rule(),
    )
  let assert True = list.length(results) == 1
}
