import glance
import gleam/list
import gleeunit/should
import glinter/rule.{type LintResult}
import glinter/rules/missing_labels
import glinter/walker

fn lint_string(source: String) -> List(LintResult) {
  let assert Ok(module) = glance.module(source)
  let r = missing_labels.rule()
  let data = walker.collect(module)
  r.check(data, source)
  |> list.map(fn(result) {
    rule.LintResult(..result, file: "test.gleam", severity: r.default_severity)
  })
}

pub fn detects_missing_label_test() {
  let results =
    lint_string(
      "pub fn greet(name name: String) { name }
pub fn main() { greet(\"world\") }",
    )
  list.length(results) |> should.equal(1)
  let assert [result] = results
  result.rule |> should.equal("missing_labels")
  result.severity |> should.equal(rule.Warning)
}

pub fn ignores_correctly_labeled_call_test() {
  let results =
    lint_string(
      "pub fn greet(name name: String) { name }
pub fn main() { greet(name: \"world\") }",
    )
  list.length(results) |> should.equal(0)
}

pub fn ignores_function_without_labels_test() {
  let results =
    lint_string(
      "pub fn add(a: Int, b: Int) { a + b }
pub fn main() { add(1, 2) }",
    )
  list.length(results) |> should.equal(0)
}

pub fn ignores_unknown_function_test() {
  let results = lint_string("pub fn main() { unknown_fn(1, 2) }")
  list.length(results) |> should.equal(0)
}

pub fn ignores_mismatched_arg_count_test() {
  let results =
    lint_string(
      "pub fn greet(name name: String) { name }
pub fn main() { greet(\"a\", \"b\") }",
    )
  list.length(results) |> should.equal(0)
}

pub fn detects_multiple_missing_labels_test() {
  let results =
    lint_string(
      "pub fn greet(name name: String, greeting greeting: String) { greeting <> name }
pub fn main() { greet(\"world\", \"hello\") }",
    )
  list.length(results) |> should.equal(2)
}

pub fn detects_call_in_nested_block_test() {
  let results =
    lint_string(
      "pub fn greet(name name: String) { name }
pub fn main() { { greet(\"world\") } }",
    )
  list.length(results) |> should.equal(1)
}

pub fn ignores_partial_label_present_test() {
  let results =
    lint_string(
      "pub fn greet(name name: String, greeting greeting: String) { greeting <> name }
pub fn main() { greet(name: \"world\", \"hello\") }",
    )
  list.length(results) |> should.equal(1)
}
