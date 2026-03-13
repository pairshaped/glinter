import glance
import gleam/list
import gleeunit/should
import glinter/rule.{type LintResult}
import glinter/rules/deep_nesting
import glinter/walker

fn lint_string(source: String) -> List(LintResult) {
  let assert Ok(module) = glance.module(source)
  walker.walk_module(module, [deep_nesting.rule()], source, "test.gleam")
}

pub fn ignores_shallow_nesting_test() {
  // 5 levels: fn body -> block -> block -> block -> block -> block
  let results =
    lint_string("pub fn f() { { { { { 1 } } } } }")
  list.length(results) |> should.equal(0)
}

pub fn detects_deep_nesting_test() {
  // 6 levels: fn body -> block -> block -> block -> block -> block -> block
  let results =
    lint_string("pub fn f() { { { { { { 1 } } } } } }")
  list.length(results) |> should.equal(1)
  let assert [result] = results
  result.rule |> should.equal("deep_nesting")
  result.severity |> should.equal(rule.Warning)
}

pub fn detects_deep_case_nesting_test() {
  let results =
    lint_string(
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
    )
  list.length(results) |> should.equal(1)
}

pub fn detects_deep_fn_nesting_test() {
  let results =
    lint_string(
      "pub fn f() {
        fn() { fn() { fn() { fn() { fn() { 1 } } } } }
      }",
    )
  list.length(results) |> should.equal(1)
}

pub fn reports_only_first_crossing_test() {
  // 7 levels deep — should still only report once
  let results =
    lint_string("pub fn f() { { { { { { { 1 } } } } } } }")
  list.length(results) |> should.equal(1)
}
