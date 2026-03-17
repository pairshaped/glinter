import gleam/list
import glinter/rule
import glinter/rules/error_context_lost
import glinter/test_helpers

pub fn detects_map_error_with_discard_test() {
  let results =
    test_helpers.lint_string_rule(
      "import gleam/result
pub fn bad(r) { result.map_error(r, fn(_) { \"oops\" }) }",
      error_context_lost.rule(),
    )
  let assert True = list.length(results) == 1
  let assert [result] = results
  let assert True = result.rule == "error_context_lost"
  let assert True = result.severity == rule.Warning
}

pub fn ignores_replace_error_test() {
  let results =
    test_helpers.lint_string_rule(
      "import gleam/result
pub fn ok(r) { result.replace_error(r, \"oops\") }",
      error_context_lost.rule(),
    )
  let assert True = results == []
}

pub fn ignores_map_error_with_named_param_test() {
  let results =
    test_helpers.lint_string_rule(
      "import gleam/result
pub fn ok(r) { result.map_error(r, fn(e) { wrap(e) }) }",
      error_context_lost.rule(),
    )
  let assert True = results == []
}

pub fn ignores_unrelated_calls_test() {
  let results =
    test_helpers.lint_string_rule(
      "import gleam/list
pub fn ok(xs) { list.map(xs, fn(_) { 1 }) }",
      error_context_lost.rule(),
    )
  let assert True = results == []
}
