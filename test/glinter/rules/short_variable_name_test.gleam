import glance
import gleam/list
import gleeunit/should
import glinter/rule.{type LintResult}
import glinter/rules/short_variable_name
import glinter/walker

fn lint_string(source: String) -> List(LintResult) {
  let assert Ok(module) = glance.module(source)
  walker.walk_module(module, [short_variable_name.rule()], source, "test.gleam")
}

pub fn detects_single_letter_name_test() {
  let results = lint_string("pub fn bad() { let x = 1 \n x }")
  list.length(results) |> should.equal(1)
  let assert [result] = results
  result.rule |> should.equal("short_variable_name")
  result.severity |> should.equal(rule.Warning)
}

pub fn ignores_descriptive_name_test() {
  let results = lint_string("pub fn ok() { let count = 1 \n count }")
  list.length(results) |> should.equal(0)
}

pub fn ignores_single_letter_fn_param_test() {
  let results =
    lint_string(
      "import gleam/list
pub fn ok() { list.map([1], fn(x) { x }) }",
    )
  list.length(results) |> should.equal(0)
}

pub fn ignores_case_clause_pattern_test() {
  let results =
    lint_string("pub fn ok(val) { case val { x -> x } }")
  list.length(results) |> should.equal(0)
}

pub fn detects_multiple_short_names_test() {
  let results =
    lint_string("pub fn bad() { let a = 1 \n let b = 2 \n a + b }")
  list.length(results) |> should.equal(2)
}
