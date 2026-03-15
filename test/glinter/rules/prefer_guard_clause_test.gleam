import glance
import gleam/list
import gleeunit/should
import glinter/rule.{type LintResult}
import glinter/rules/prefer_guard_clause
import glinter/walker

fn lint_string(source: String) -> List(LintResult) {
  let assert Ok(module) = glance.module(source)
  let r = prefer_guard_clause.rule()
  let data = walker.collect(module)
  r.check(data, source)
  |> list.map(fn(result) {
    rule.LintResult(..result, file: "test.gleam", severity: r.default_severity)
  })
}

pub fn detects_true_false_case_test() {
  let results =
    lint_string(
      "pub fn f(x) {
        case x {
          True -> { do_something() \n do_more() }
          False -> Error(Nil)
        }
      }",
    )
  list.length(results) |> should.equal(1)
  let assert [result] = results
  result.rule |> should.equal("prefer_guard_clause")
  result.severity |> should.equal(rule.Warning)
}

pub fn detects_false_true_order_test() {
  let results =
    lint_string(
      "pub fn f(x) {
        case x {
          False -> Error(Nil)
          True -> { do_something() \n do_more() }
        }
      }",
    )
  list.length(results) |> should.equal(1)
}

pub fn ignores_multi_branch_case_test() {
  let results =
    lint_string(
      "pub fn f(x) {
        case x {
          True -> 1
          False -> 2
          _ -> 3
        }
      }",
    )
  list.length(results) |> should.equal(0)
}

pub fn ignores_non_boolean_patterns_test() {
  let results =
    lint_string(
      "pub fn f(x) {
        case x {
          Ok(v) -> v
          Error(_) -> 0
        }
      }",
    )
  list.length(results) |> should.equal(0)
}

pub fn ignores_case_with_guard_test() {
  let results =
    lint_string(
      "pub fn f(x) {
        case x {
          True if x -> 1
          False -> 0
        }
      }",
    )
  list.length(results) |> should.equal(0)
}

pub fn ignores_multi_statement_body_test() {
  let results =
    lint_string(
      "pub fn f(x) {
        let y = compute()
        case x {
          True -> y
          False -> 0
        }
      }",
    )
  list.length(results) |> should.equal(0)
}

pub fn ignores_both_branches_block_test() {
  let results =
    lint_string(
      "pub fn f(x) {
        case x {
          True -> { do_a() \n do_b() }
          False -> { do_c() \n do_d() }
        }
      }",
    )
  list.length(results) |> should.equal(0)
}
