import glance
import gleam/list
import gleeunit/should
import glinter/rule.{type LintResult}
import glinter/rules/label_possible
import glinter/walker

fn lint_string(source: String) -> List(LintResult) {
  let assert Ok(module) = glance.module(source)
  let r = label_possible.rule()
  let data = walker.collect(module)
  r.check(data, source)
  |> list.map(fn(result) {
    rule.LintResult(..result, file: "test.gleam", severity: r.default_severity)
  })
}

pub fn detects_unlabeled_param_test() {
  let results =
    lint_string(
      "pub fn greet(name: String, greeting: String) { greeting <> name }",
    )
  list.length(results) |> should.equal(2)
  let assert [result, ..] = results
  result.rule |> should.equal("label_possible")
  result.severity |> should.equal(rule.Warning)
}

pub fn ignores_single_param_test() {
  let results = lint_string("pub fn greet(name: String) { name }")
  list.length(results) |> should.equal(0)
}

pub fn ignores_all_labeled_test() {
  let results =
    lint_string(
      "pub fn greet(name name: String, greeting greeting: String) { greeting <> name }",
    )
  list.length(results) |> should.equal(0)
}

pub fn detects_partial_labels_test() {
  let results =
    lint_string(
      "pub fn greet(name name: String, greeting: String) { greeting <> name }",
    )
  list.length(results) |> should.equal(1)
}

pub fn ignores_one_param_no_label_test() {
  let results = lint_string("pub fn f(x) { x }")
  list.length(results) |> should.equal(0)
}

pub fn detects_three_unlabeled_params_test() {
  let results = lint_string("pub fn f(a: Int, b: Int, c: Int) { a + b + c }")
  list.length(results) |> should.equal(3)
}
