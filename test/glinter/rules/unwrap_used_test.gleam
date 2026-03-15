import glance
import gleam/list
import gleeunit/should
import glinter/rule.{type LintResult}
import glinter/rules/unwrap_used
import glinter/walker

fn lint_string(source: String) -> List(LintResult) {
  let assert Ok(module) = glance.module(source)
  let r = unwrap_used.rule()
  let data = walker.collect(module)
  r.check(data, source)
  |> list.map(fn(result) {
    rule.LintResult(..result, file: "test.gleam", severity: r.default_severity)
  })
}

pub fn detects_result_unwrap_test() {
  let results =
    lint_string(
      "import gleam/result
pub fn bad() { result.unwrap(Ok(1), 0) }",
    )
  list.length(results) |> should.equal(1)
  let assert [result] = results
  result.rule |> should.equal("unwrap_used")
  result.severity |> should.equal(rule.Warning)
}

pub fn detects_option_unwrap_test() {
  let results =
    lint_string(
      "import gleam/option
pub fn bad() { option.unwrap(option.Some(1), 0) }",
    )
  list.length(results) |> should.equal(1)
}

pub fn detects_lazy_unwrap_test() {
  let results =
    lint_string(
      "import gleam/result
pub fn bad() { result.lazy_unwrap(Ok(1), fn() { 0 }) }",
    )
  list.length(results) |> should.equal(1)
}

pub fn ignores_other_module_unwrap_test() {
  let results =
    lint_string(
      "import my/utils
pub fn ok() { utils.unwrap(thing) }",
    )
  list.length(results) |> should.equal(0)
}

pub fn ignores_result_map_test() {
  let results =
    lint_string(
      "import gleam/result
pub fn ok() { result.map(Ok(1), fn(x) { x + 1 }) }",
    )
  list.length(results) |> should.equal(0)
}
