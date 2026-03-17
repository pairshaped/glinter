import gleam/list
import glinter/rule
import glinter/rules/deep_nesting
import glinter/test_helpers

pub fn ignores_shallow_nesting_test() {
  // 5 levels: fn body -> block -> block -> block -> block -> block
  let results =
    test_helpers.lint_string_rule(
      "pub fn f() { { { { { 1 } } } } }",
      deep_nesting.rule(),
    )
  let assert True = results == []
}

pub fn detects_deep_nesting_test() {
  // 6 levels: fn body -> block -> block -> block -> block -> block -> block
  let results =
    test_helpers.lint_string_rule(
      "pub fn f() { { { { { { 1 } } } } } }",
      deep_nesting.rule(),
    )
  let assert True = list.length(results) == 1
  let assert [result] = results
  let assert True = result.rule == "deep_nesting"
  let assert True = result.severity == rule.Warning
}

pub fn detects_deep_case_nesting_test() {
  let results =
    test_helpers.lint_string_rule(
      "pub fn f(a, b, c, d, e, g) {
        case a {
          _ -> case b {
            _ -> case c {
              _ -> case d {
                _ -> case e {
                  _ -> case g {
                    _ -> 1
                  }
                }
              }
            }
          }
        }
      }",
      deep_nesting.rule(),
    )
  let assert True = list.length(results) == 1
}

pub fn detects_deep_fn_nesting_test() {
  let results =
    test_helpers.lint_string_rule(
      "pub fn f() {
        fn() { fn() { fn() { fn() { fn() { 1 } } } } }
      }",
      deep_nesting.rule(),
    )
  let assert True = list.length(results) == 1
}

pub fn reports_only_first_crossing_test() {
  // 7 levels deep — should still only report once
  let results =
    test_helpers.lint_string_rule(
      "pub fn f() { { { { { { { 1 } } } } } } }",
      deep_nesting.rule(),
    )
  let assert True = list.length(results) == 1
}
