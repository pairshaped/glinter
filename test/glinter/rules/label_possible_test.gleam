import gleam/list
import glinter/rule
import glinter/rules/label_possible
import glinter/test_helpers

pub fn detects_unlabeled_param_test() {
  let results =
    test_helpers.lint_string_rule(
      "pub fn greet(name: String, greeting: String) { greeting <> name }",
      label_possible.rule(),
    )
  let assert True = list.length(results) == 2
  let assert [result, ..] = results
  let assert True = result.rule == "label_possible"
  let assert True = result.severity == rule.Warning
}

pub fn ignores_single_param_test() {
  let results =
    test_helpers.lint_string_rule(
      "pub fn greet(name: String) { name }",
      label_possible.rule(),
    )
  let assert True = results == []
}

pub fn ignores_all_labeled_test() {
  let results =
    test_helpers.lint_string_rule(
      "pub fn greet(name name: String, greeting greeting: String) { greeting <> name }",
      label_possible.rule(),
    )
  let assert True = results == []
}

pub fn detects_partial_labels_test() {
  let results =
    test_helpers.lint_string_rule(
      "pub fn greet(name name: String, greeting: String) { greeting <> name }",
      label_possible.rule(),
    )
  let assert True = list.length(results) == 1
}

pub fn ignores_one_param_no_label_test() {
  let results =
    test_helpers.lint_string_rule("pub fn f(x) { x }", label_possible.rule())
  let assert True = results == []
}

pub fn detects_three_unlabeled_params_test() {
  let results =
    test_helpers.lint_string_rule(
      "pub fn f(a: Int, b: Int, c: Int) { a + b + c }",
      label_possible.rule(),
    )
  let assert True = list.length(results) == 3
}

pub fn ignores_external_function_test() {
  let results =
    test_helpers.lint_string_rule(
      "@external(erlang, \"mymod\", \"myfn\")
pub fn my_external(a: Int, b: Int) -> Int",
      label_possible.rule(),
    )
  let assert True = results == []
}

pub fn ignores_private_function_with_two_params_test() {
  let results =
    test_helpers.lint_string_rule(
      "fn helper(a: Int, b: Int) { a + b }",
      label_possible.rule(),
    )
  let assert True = results == []
}

pub fn detects_private_function_with_three_params_test() {
  let results =
    test_helpers.lint_string_rule(
      "fn helper(a: Int, b: Int, c: Int) { a + b + c }",
      label_possible.rule(),
    )
  let assert True = list.length(results) == 3
}

pub fn ignores_function_with_callback_param_test() {
  let results =
    test_helpers.lint_string_rule(
      "pub fn try_it(result: Result(a, e), next: fn(a) -> b) { todo }",
      label_possible.rule(),
    )
  let assert True = results == []
}
