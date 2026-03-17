import gleam/list
import glinter/rules/panic_without_message
import glinter/test_helpers

pub fn detects_panic_without_message_test() {
  let results =
    test_helpers.lint_string_rule(
      "pub fn main() { panic }",
      panic_without_message.rule(),
    )
  let assert True = list.length(results) == 1
  let assert [result] = results
  let assert True = result.rule == "panic_without_message"
}

pub fn ignores_panic_with_message_test() {
  let results =
    test_helpers.lint_string_rule(
      "pub fn main() { panic as \"should never happen\" }",
      panic_without_message.rule(),
    )
  let assert True = results == []
}

pub fn ignores_non_panic_test() {
  let results =
    test_helpers.lint_string_rule(
      "pub fn main() { Nil }",
      panic_without_message.rule(),
    )
  let assert True = results == []
}
