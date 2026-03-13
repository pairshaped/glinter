import glance
import gleam/list
import gleeunit/should
import glinter/rule.{type LintResult}
import glinter/rules/discarded_result
import glinter/walker

fn lint_string(source: String) -> List(LintResult) {
  let assert Ok(module) = glance.module(source)
  walker.walk_module(module, [discarded_result.rule()], source, "test.gleam")
}

pub fn detects_discarded_result_test() {
  let results = lint_string("pub fn bad() { let _ = get() \n 1 }")
  list.length(results) |> should.equal(1)
  let assert [result] = results
  result.rule |> should.equal("discarded_result")
  result.severity |> should.equal(rule.Warning)
}

pub fn ignores_named_discard_test() {
  let results = lint_string("pub fn ok() { let _result = get() \n 1 }")
  list.length(results) |> should.equal(0)
}

pub fn ignores_regular_assignment_test() {
  let results = lint_string("pub fn ok() { let x = 1 \n x }")
  list.length(results) |> should.equal(0)
}

pub fn ignores_let_assert_test() {
  let results =
    lint_string("pub fn ok() { let assert Ok(x) = get() \n x }")
  list.length(results) |> should.equal(0)
}
