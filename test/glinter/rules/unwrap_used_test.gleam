import gleam/list
import glinter/rule
import glinter/rules/unwrap_used
import glinter/test_helpers

pub fn detects_result_unwrap_test() {
  let results =
    test_helpers.lint_string_rule(
      "import gleam/result
pub fn bad() { result.unwrap(Ok(1), 0) }",
      unwrap_used.rule(),
    )
  let assert True = list.length(results) == 1
  let assert [result] = results
  let assert True = result.rule == "unwrap_used"
  let assert True = result.severity == rule.Warning
}

pub fn detects_option_unwrap_test() {
  let results =
    test_helpers.lint_string_rule(
      "import gleam/option
pub fn bad() { option.unwrap(option.Some(1), 0) }",
      unwrap_used.rule(),
    )
  let assert True = list.length(results) == 1
}

pub fn detects_lazy_unwrap_test() {
  let results =
    test_helpers.lint_string_rule(
      "import gleam/result
pub fn bad() { result.lazy_unwrap(Ok(1), fn() { 0 }) }",
      unwrap_used.rule(),
    )
  let assert True = list.length(results) == 1
}

pub fn ignores_other_module_unwrap_test() {
  let results =
    test_helpers.lint_string_rule(
      "import my/utils
pub fn ok() { utils.unwrap(thing) }",
      unwrap_used.rule(),
    )
  let assert True = results == []
}

pub fn ignores_result_map_test() {
  let results =
    test_helpers.lint_string_rule(
      "import gleam/result
pub fn ok() { result.map(Ok(1), fn(x) { x + 1 }) }",
      unwrap_used.rule(),
    )
  let assert True = results == []
}
