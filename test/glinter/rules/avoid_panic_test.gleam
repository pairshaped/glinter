import gleam/list
import glinter/rule
import glinter/rules/avoid_panic
import glinter/test_helpers

pub fn detects_panic_test() {
  let results =
    test_helpers.lint_string_rule("pub fn bad() { panic }", avoid_panic.rule())
  let assert True = list.length(results) == 1
  let assert [result] = results
  let assert True = result.rule == "avoid_panic"
  let assert True = result.severity == rule.Error
}

pub fn detects_panic_with_message_test() {
  let results =
    test_helpers.lint_string_rule(
      "pub fn bad() { panic as \"oh no\" }",
      avoid_panic.rule(),
    )
  let assert True = list.length(results) == 1
}

pub fn ignores_clean_code_test() {
  let results =
    test_helpers.lint_string_rule("pub fn good() { Ok(1) }", avoid_panic.rule())
  let assert True = results == []
}

pub fn detects_nested_panic_test() {
  let results =
    test_helpers.lint_string_rule(
      "pub fn bad() { { panic } }",
      avoid_panic.rule(),
    )
  let assert True = list.length(results) == 1
}
