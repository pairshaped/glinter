import gleam/list
import glinter/rules/todo_without_message
import glinter/test_helpers

pub fn detects_todo_without_message_test() {
  let results =
    test_helpers.lint_string_rule(
      "pub fn main() { todo }",
      todo_without_message.rule(),
    )
  let assert True = list.length(results) == 1
  let assert [result] = results
  let assert True = result.rule == "todo_without_message"
}

pub fn ignores_todo_with_message_test() {
  let results =
    test_helpers.lint_string_rule(
      "pub fn main() { todo as \"implement auth\" }",
      todo_without_message.rule(),
    )
  let assert True = results == []
}

pub fn ignores_non_todo_test() {
  let results =
    test_helpers.lint_string_rule(
      "pub fn main() { Nil }",
      todo_without_message.rule(),
    )
  let assert True = results == []
}
