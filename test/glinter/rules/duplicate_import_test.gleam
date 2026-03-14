import glance
import gleam/list
import gleeunit/should
import glinter/rule.{type LintResult}
import glinter/rules/duplicate_import
import glinter/walker

fn lint_string(source: String) -> List(LintResult) {
  let assert Ok(module) = glance.module(source)
  walker.walk_module(
    module,
    [duplicate_import.rule()],
    source,
    "test.gleam",
  )
}

pub fn detects_duplicate_import_test() {
  let results =
    lint_string(
      "import gleam/list
       import gleam/list",
    )
  list.length(results) |> should.equal(1)
  let assert [result] = results
  result.rule |> should.equal("duplicate_import")
  result.message
  |> should.equal("Module 'gleam/list' is imported more than once")
}

pub fn ignores_unique_imports_test() {
  let results =
    lint_string(
      "import gleam/list
       import gleam/string",
    )
  list.length(results) |> should.equal(0)
}

pub fn ignores_single_import_test() {
  let results = lint_string("import gleam/list")
  list.length(results) |> should.equal(0)
}

pub fn detects_triple_import_test() {
  let results =
    lint_string(
      "import gleam/list
       import gleam/string
       import gleam/list
       import gleam/list",
    )
  list.length(results) |> should.equal(2)
}
