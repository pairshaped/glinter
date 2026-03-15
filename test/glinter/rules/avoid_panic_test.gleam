import glance
import gleam/list
import gleeunit/should
import glinter/rule.{type LintResult}
import glinter/rules/avoid_panic
import glinter/walker

fn lint_string(source: String) -> List(LintResult) {
  let assert Ok(module) = glance.module(source)
  let r = avoid_panic.rule()
  let data = walker.collect(module)
  r.check(data, source)
  |> list.map(fn(result) {
    rule.LintResult(..result, file: "test.gleam", severity: r.default_severity)
  })
}

pub fn detects_panic_test() {
  let results = lint_string("pub fn bad() { panic }")
  list.length(results) |> should.equal(1)
  let assert [result] = results
  result.rule |> should.equal("avoid_panic")
  result.severity |> should.equal(rule.Error)
}

pub fn detects_panic_with_message_test() {
  let results = lint_string("pub fn bad() { panic as \"oh no\" }")
  list.length(results) |> should.equal(1)
}

pub fn ignores_clean_code_test() {
  let results = lint_string("pub fn good() { Ok(1) }")
  list.length(results) |> should.equal(0)
}

pub fn detects_nested_panic_test() {
  let results = lint_string("pub fn bad() { { panic } }")
  list.length(results) |> should.equal(1)
}
