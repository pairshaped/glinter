import glance
import gleam/list
import gleeunit/should
import glinter/rule.{type LintResult, Error, LintResult, Rule, Warning}
import glinter/walker

/// Helper: parse source and run a rule
fn lint_string(source: String, rules: List(rule.Rule)) -> List(LintResult) {
  let assert Ok(module) = glance.module(source)
  let data = walker.collect(module)
  rules
  |> list.flat_map(fn(r) {
    r.check(data, source)
    |> list.map(fn(result) {
      LintResult(..result, file: "test.gleam", severity: r.default_severity)
    })
  })
}

fn check_for_panic(
  data: rule.ModuleData,
  _source: String,
) -> List(LintResult) {
  data.expressions
  |> list.flat_map(fn(expr) {
    case expr {
      glance.Panic(location, _) -> [
        LintResult(
          rule: "test_panic",
          severity: Error,
          file: "",
          location: location,
          message: "found panic",
        ),
      ]
      _ -> []
    }
  })
}

/// A dummy rule that flags every Panic expression
fn panic_rule() -> rule.Rule {
  Rule(name: "test_panic", default_severity: Error, check: check_for_panic)
}

pub fn walk_finds_panic_in_function_test() {
  let results = lint_string("pub fn bad() { panic }", [panic_rule()])
  list.length(results) |> should.equal(1)
}

pub fn walk_finds_nothing_in_clean_code_test() {
  let results = lint_string("pub fn good() { 1 }", [panic_rule()])
  list.length(results) |> should.equal(0)
}

pub fn walk_recurses_into_blocks_test() {
  let results = lint_string("pub fn bad() { { panic } }", [panic_rule()])
  list.length(results) |> should.equal(1)
}

pub fn walk_recurses_into_case_branches_test() {
  let results =
    lint_string("pub fn bad(x) { case x { _ -> panic } }", [panic_rule()])
  list.length(results) |> should.equal(1)
}

pub fn walk_fills_in_file_field_test() {
  let results = lint_string("pub fn bad() { panic }", [panic_rule()])
  let assert [result] = results
  result.file |> should.equal("test.gleam")
}

pub fn walk_applies_rule_severity_override_test() {
  // Rule hardcodes Error in its check fn, but default_severity is Warning
  let overridden_rule = Rule(..panic_rule(), default_severity: Warning)
  let results = lint_string("pub fn bad() { panic }", [overridden_rule])
  let assert [result] = results
  result.severity |> should.equal(Warning)
}
