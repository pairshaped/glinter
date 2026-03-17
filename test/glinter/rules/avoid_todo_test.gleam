import gleam/list
import glinter/rule
import glinter/rules/avoid_todo
import glinter/test_helpers

pub fn detects_todo_test() {
  let results =
    test_helpers.lint_string_rule("pub fn stub() { todo }", avoid_todo.rule())
  let assert True = list.length(results) == 1
  let assert [result] = results
  let assert True = result.rule == "avoid_todo"
  let assert True = result.severity == rule.Error
}

pub fn detects_todo_with_message_test() {
  let results =
    test_helpers.lint_string_rule(
      "pub fn stub() { todo as \"implement later\" }",
      avoid_todo.rule(),
    )
  let assert True = list.length(results) == 1
}

pub fn ignores_clean_code_test() {
  let results =
    test_helpers.lint_string_rule("pub fn good() { Ok(1) }", avoid_todo.rule())
  let assert True = results == []
}
