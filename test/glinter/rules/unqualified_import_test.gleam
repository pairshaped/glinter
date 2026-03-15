import glance
import gleam/list
import gleeunit/should
import glinter/rule.{type LintResult}
import glinter/rules/unqualified_import
import glinter/walker

fn lint_string(source: String) -> List(LintResult) {
  let assert Ok(module) = glance.module(source)
  let r = unqualified_import.rule()
  let data = walker.collect(module)
  r.check(data, source)
  |> list.map(fn(result) {
    rule.LintResult(..result, file: "test.gleam", severity: r.default_severity)
  })
}

pub fn detects_unqualified_function_import_test() {
  let results = lint_string("import gleam/list.{map}")
  list.length(results) |> should.equal(1)
  let assert [result] = results
  result.rule |> should.equal("unqualified_import")
  result.message
  |> should.equal(
    "Function 'map' is imported unqualified from 'gleam/list', use qualified access instead",
  )
}

pub fn detects_multiple_unqualified_function_imports_test() {
  let results = lint_string("import gleam/list.{map, filter, fold}")
  list.length(results) |> should.equal(3)
}

pub fn ignores_qualified_import_test() {
  let results = lint_string("import gleam/list")
  list.length(results) |> should.equal(0)
}

pub fn ignores_unqualified_type_import_test() {
  let results = lint_string("import gleam/option.{type Option}")
  list.length(results) |> should.equal(0)
}

pub fn ignores_constructor_imports_test() {
  let results = lint_string("import gleam/option.{type Option, None, Some}")
  // Constructors (PascalCase) are fine, only functions/constants flagged
  list.length(results) |> should.equal(0)
}

pub fn ignores_aliased_import_test() {
  let results = lint_string("import gleam/list as l")
  list.length(results) |> should.equal(0)
}

pub fn mixed_constructors_and_functions_test() {
  let results =
    lint_string("import gleam/option.{type Option, None, Some, unwrap}")
  // Only unwrap (lowercase) is flagged
  list.length(results) |> should.equal(1)
  let assert [result] = results
  result.message
  |> should.equal(
    "Function 'unwrap' is imported unqualified from 'gleam/option', use qualified access instead",
  )
}
