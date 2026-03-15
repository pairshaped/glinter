import glance
import gleam/list
import gleeunit/should
import glinter/rule.{type LintResult}
import glinter/rules/todo_without_message
import glinter/walker

fn lint_string(source: String) -> List(LintResult) {
  let assert Ok(module) = glance.module(source)
  let r = todo_without_message.rule()
  let data = walker.collect(module)
  r.check(data, source)
  |> list.map(fn(result) {
    rule.LintResult(..result, file: "test.gleam", severity: r.default_severity)
  })
}

pub fn detects_todo_without_message_test() {
  let results = lint_string("pub fn main() { todo }")
  list.length(results) |> should.equal(1)
  let assert [result] = results
  result.rule |> should.equal("todo_without_message")
}

pub fn ignores_todo_with_message_test() {
  let results = lint_string("pub fn main() { todo as \"implement auth\" }")
  list.length(results) |> should.equal(0)
}

pub fn ignores_non_todo_test() {
  let results = lint_string("pub fn main() { Nil }")
  list.length(results) |> should.equal(0)
}
