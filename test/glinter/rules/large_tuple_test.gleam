import glance
import gleam/list
import gleeunit/should
import glinter/rule.{type LintResult}
import glinter/rules/large_tuple
import glinter/walker

fn lint_string(source: String) -> List(LintResult) {
  let assert Ok(module) = glance.module(source)
  walker.walk_module(module, [large_tuple.rule()], source, "test.gleam")
}

pub fn detects_large_tuple_test() {
  let results = lint_string("pub fn main() { #(1, 2, 3, 4) }")
  list.length(results) |> should.equal(1)
  let assert [result] = results
  result.rule |> should.equal("large_tuple")
  result.message
  |> should.equal(
    "Tuple has 4 elements, consider using a custom type instead",
  )
}

pub fn ignores_small_tuple_test() {
  let results = lint_string("pub fn main() { #(1, 2, 3) }")
  list.length(results) |> should.equal(0)
}

pub fn ignores_pair_test() {
  let results = lint_string("pub fn main() { #(1, 2) }")
  list.length(results) |> should.equal(0)
}

pub fn detects_five_element_tuple_test() {
  let results = lint_string("pub fn main() { #(1, 2, 3, 4, 5) }")
  list.length(results) |> should.equal(1)
  let assert [result] = results
  result.message
  |> should.equal(
    "Tuple has 5 elements, consider using a custom type instead",
  )
}
