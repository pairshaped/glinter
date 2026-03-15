import glance
import gleam/list
import gleeunit/should
import glinter/rule.{type LintResult}
import glinter/rules/string_inspect
import glinter/walker

fn lint_string(source: String) -> List(LintResult) {
  let assert Ok(module) = glance.module(source)
  let r = string_inspect.rule()
  let data = walker.collect(module)
  r.check(data, source)
  |> list.map(fn(result) {
    rule.LintResult(..result, file: "test.gleam", severity: r.default_severity)
  })
}

pub fn detects_string_inspect_test() {
  let results = lint_string("pub fn main() { string.inspect(42) }")
  list.length(results) |> should.equal(1)
  let assert [result] = results
  result.rule |> should.equal("string_inspect")
}

pub fn ignores_other_string_functions_test() {
  let results = lint_string("pub fn main() { string.length(\"hi\") }")
  list.length(results) |> should.equal(0)
}

pub fn ignores_other_module_inspect_test() {
  let results = lint_string("pub fn main() { other.inspect(42) }")
  list.length(results) |> should.equal(0)
}
