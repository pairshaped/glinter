import glance
import gleeunit/should
import glinter/analysis

fn count(source: String) -> Int {
  let assert Ok(module) = glance.module(source)
  let assert [def, ..] = module.functions
  analysis.count_branches(def.definition.body)
}

pub fn counts_case_expression_test() {
  count("pub fn f(x) { case x { _ -> 1 } }")
  |> should.equal(1)
}

pub fn counts_nested_case_test() {
  count("pub fn f(x) { case x { _ -> case x { _ -> 1 } } }")
  |> should.equal(2)
}

pub fn counts_anonymous_fn_test() {
  count("pub fn f() { fn() { 1 } }")
  |> should.equal(1)
}

pub fn counts_nested_block_test() {
  count("pub fn f() { { 1 } }")
  |> should.equal(1)
}

pub fn counts_zero_for_simple_function_test() {
  count("pub fn f() { 1 }")
  |> should.equal(0)
}

pub fn counts_multiple_branches_test() {
  count(
    "pub fn f(x, y) {
      case x { _ -> 1 }
      case y { _ -> 2 }
      fn() { 3 }
    }",
  )
  |> should.equal(3)
}
