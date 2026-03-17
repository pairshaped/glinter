import gleam/list
import glinter/rules/string_inspect
import glinter/test_helpers

pub fn detects_string_inspect_test() {
  let results =
    test_helpers.lint_string_rule(
      "pub fn main() { string.inspect(42) }",
      string_inspect.rule(),
    )
  let assert True = list.length(results) == 1
  let assert [result] = results
  let assert True = result.rule == "string_inspect"
}

pub fn ignores_other_string_functions_test() {
  let results =
    test_helpers.lint_string_rule(
      "pub fn main() { string.length(\"hi\") }",
      string_inspect.rule(),
    )
  let assert True = results == []
}

pub fn ignores_other_module_inspect_test() {
  let results =
    test_helpers.lint_string_rule(
      "pub fn main() { other.inspect(42) }",
      string_inspect.rule(),
    )
  let assert True = results == []
}
