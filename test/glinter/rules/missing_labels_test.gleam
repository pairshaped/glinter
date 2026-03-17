import gleam/list
import glinter/rule
import glinter/rules/missing_labels
import glinter/test_helpers

pub fn detects_missing_label_test() {
  let results =
    test_helpers.lint_string_rule(
      "pub fn greet(name name: String) { name }
pub fn main() { greet(\"world\") }",
      missing_labels.rule(),
    )
  let assert True = list.length(results) == 1
  let assert [result] = results
  let assert True = result.rule == "missing_labels"
  let assert True = result.severity == rule.Warning
}

pub fn ignores_correctly_labeled_call_test() {
  let results =
    test_helpers.lint_string_rule(
      "pub fn greet(name name: String) { name }
pub fn main() { greet(name: \"world\") }",
      missing_labels.rule(),
    )
  let assert True = results == []
}

pub fn ignores_function_without_labels_test() {
  let results =
    test_helpers.lint_string_rule(
      "pub fn add(a: Int, b: Int) { a + b }
pub fn main() { add(1, 2) }",
      missing_labels.rule(),
    )
  let assert True = results == []
}

pub fn ignores_unknown_function_test() {
  let results =
    test_helpers.lint_string_rule(
      "pub fn main() { unknown_fn(1, 2) }",
      missing_labels.rule(),
    )
  let assert True = results == []
}

pub fn ignores_mismatched_arg_count_test() {
  let results =
    test_helpers.lint_string_rule(
      "pub fn greet(name name: String) { name }
pub fn main() { greet(\"a\", \"b\") }",
      missing_labels.rule(),
    )
  let assert True = results == []
}

pub fn detects_multiple_missing_labels_test() {
  let results =
    test_helpers.lint_string_rule(
      "pub fn greet(name name: String, greeting greeting: String) { greeting <> name }
pub fn main() { greet(\"world\", \"hello\") }",
      missing_labels.rule(),
    )
  let assert True = list.length(results) == 2
}

pub fn detects_call_in_nested_block_test() {
  let results =
    test_helpers.lint_string_rule(
      "pub fn greet(name name: String) { name }
pub fn main() { { greet(\"world\") } }",
      missing_labels.rule(),
    )
  let assert True = list.length(results) == 1
}

pub fn ignores_partial_label_present_test() {
  let results =
    test_helpers.lint_string_rule(
      "pub fn greet(name name: String, greeting greeting: String) { greeting <> name }
pub fn main() { greet(name: \"world\", \"hello\") }",
      missing_labels.rule(),
    )
  let assert True = list.length(results) == 1
}
