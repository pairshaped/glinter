import glance
import gleam/int
import gleam/list
import gleam/string
import gleeunit/should
import glinter/rule.{type LintResult}
import glinter/rules/module_complexity
import glinter/walker

fn lint_string(source: String) -> List(LintResult) {
  let assert Ok(module) = glance.module(source)
  walker.walk_module(
    module,
    [module_complexity.rule()],
    source,
    "test.gleam",
  )
}

fn make_function_with_cases(name: String, count: Int) -> String {
  let cases =
    list.repeat("case x { _ -> 1 }", count)
    |> string.join("\n")
  "pub fn " <> name <> "(x) {\n" <> cases <> "\n}"
}

fn make_n_functions(count: Int, cases_each: Int) -> String {
  list.repeat(Nil, count)
  |> list.index_map(fn(_, idx) {
    make_function_with_cases("f" <> int.to_string(idx), cases_each)
  })
  |> string.join("\n\n")
}

pub fn ignores_module_at_threshold_test() {
  // 5 functions x 10 cases each = 50
  let source = make_n_functions(5, 10)
  let results = lint_string(source)
  list.length(results) |> should.equal(0)
}

pub fn detects_module_over_threshold_test() {
  // 5 functions x 10 cases + 1 extra = 51
  let source =
    make_n_functions(5, 10)
    <> "\n\npub fn extra(x) { case x { _ -> 1 } }"
  let results = lint_string(source)
  list.length(results) |> should.equal(1)
  let assert [result] = results
  result.rule |> should.equal("module_complexity")
  result.severity |> should.equal(rule.Warning)
}

pub fn ignores_simple_module_test() {
  let results = lint_string("pub fn f() { 1 }\npub fn g() { 2 }")
  list.length(results) |> should.equal(0)
}
