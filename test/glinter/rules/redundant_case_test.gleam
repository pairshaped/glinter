import glance
import gleam/list
import gleeunit/should
import glinter/rule.{type LintResult}
import glinter/rules/redundant_case
import glinter/walker

fn lint_string(source: String) -> List(LintResult) {
  let assert Ok(module) = glance.module(source)
  let r = redundant_case.rule()
  let data = walker.collect(module)
  r.check(data, source)
  |> list.map(fn(result) {
    rule.LintResult(..result, file: "test.gleam", severity: r.default_severity)
  })
}

pub fn detects_single_branch_case_test() {
  let results = lint_string("pub fn bad(x) { case x { Ok(v) -> v } }")
  list.length(results) |> should.equal(1)
  let assert [result] = results
  result.rule |> should.equal("redundant_case")
  result.severity |> should.equal(rule.Warning)
}

pub fn ignores_multi_branch_case_test() {
  let results =
    lint_string("pub fn ok(x) { case x { Ok(v) -> v \n Error(_) -> 0 } }")
  list.length(results) |> should.equal(0)
}

pub fn ignores_single_branch_with_guard_test() {
  let results =
    lint_string("pub fn ok(x) { case x { v if v > 0 -> v \n _ -> 0 } }")
  list.length(results) |> should.equal(0)
}
