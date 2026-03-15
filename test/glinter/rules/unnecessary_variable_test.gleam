import glance
import gleam/list
import gleeunit/should
import glinter/rule.{type LintResult}
import glinter/rules/unnecessary_variable
import glinter/walker

fn lint_string(source: String) -> List(LintResult) {
  let assert Ok(module) = glance.module(source)
  let r = unnecessary_variable.rule()
  let data = walker.collect(module)
  r.check(data, source)
  |> list.map(fn(result) {
    rule.LintResult(..result, file: "test.gleam", severity: r.default_severity)
  })
}

pub fn detects_trailing_let_in_function_test() {
  let results = lint_string("pub fn bad() { let x = 1 \n x }")
  list.length(results) |> should.equal(1)
  let assert [result] = results
  result.rule |> should.equal("unnecessary_variable")
  result.severity |> should.equal(rule.Warning)
}

pub fn ignores_different_names_test() {
  let results = lint_string("pub fn ok() { let x = 1 \n y }")
  list.length(results) |> should.equal(0)
}

pub fn ignores_statements_between_test() {
  let results = lint_string("pub fn ok() { let x = 1 \n do_something() \n x }")
  list.length(results) |> should.equal(0)
}

pub fn detects_in_block_test() {
  let results = lint_string("pub fn bad() { { let x = 1 \n x } }")
  list.length(results) |> should.equal(1)
}

pub fn detects_in_case_branch_test() {
  let results =
    lint_string("pub fn bad(v) { case v { _ -> { let x = 1 \n x } } }")
  list.length(results) |> should.equal(1)
}

pub fn detects_in_anonymous_fn_test() {
  let results = lint_string("pub fn bad() { fn() { let x = 1 \n x } }")
  list.length(results) |> should.equal(1)
}

pub fn ignores_pattern_match_assignment_test() {
  let results = lint_string("pub fn ok() { let #(a, _) = get() \n a }")
  list.length(results) |> should.equal(0)
}
