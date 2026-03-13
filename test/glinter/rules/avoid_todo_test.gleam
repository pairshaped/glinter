import glance
import gleam/list
import gleeunit/should
import glinter/rule.{type LintResult}
import glinter/rules/avoid_todo
import glinter/walker

fn lint_string(source: String) -> List(LintResult) {
  let assert Ok(module) = glance.module(source)
  walker.walk_module(module, [avoid_todo.rule()], source, "test.gleam")
}

pub fn detects_todo_test() {
  let results = lint_string("pub fn stub() { todo }")
  list.length(results) |> should.equal(1)
  let assert [result] = results
  result.rule |> should.equal("avoid_todo")
  result.severity |> should.equal(rule.Error)
}

pub fn detects_todo_with_message_test() {
  let results = lint_string("pub fn stub() { todo as \"implement later\" }")
  list.length(results) |> should.equal(1)
}

pub fn ignores_clean_code_test() {
  let results = lint_string("pub fn good() { Ok(1) }")
  list.length(results) |> should.equal(0)
}
