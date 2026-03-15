import glance
import gleam/list
import gleeunit/should
import glinter/rule.{type LintResult}
import glinter/rules/assert_ok_pattern
import glinter/walker

fn lint_string(source: String) -> List(LintResult) {
  let assert Ok(module) = glance.module(source)
  let r = assert_ok_pattern.rule()
  let data = walker.collect(module)
  r.check(data, source)
  |> list.map(fn(result) {
    rule.LintResult(..result, file: "test.gleam", severity: r.default_severity)
  })
}

pub fn detects_let_assert_test() {
  let results = lint_string("pub fn bad() { let assert Ok(x) = get() \n x }")
  list.length(results) |> should.equal(1)
  let assert [result] = results
  result.rule |> should.equal("assert_ok_pattern")
  result.severity |> should.equal(rule.Warning)
}

pub fn ignores_regular_let_test() {
  let results = lint_string("pub fn good() { let x = 1 \n x }")
  list.length(results) |> should.equal(0)
}

pub fn ignores_case_pattern_match_test() {
  let results =
    lint_string("pub fn good(x) { case x { Ok(v) -> v \n _ -> 0 } }")
  list.length(results) |> should.equal(0)
}
