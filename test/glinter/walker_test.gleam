import glance
import gleam/list
import glinter/rule.{Error, RuleResult, V2Rule, Warning}
import glinter/test_helpers

fn check_for_panic(
  data: rule.ModuleData,
  _source: String,
) -> List(rule.RuleResult) {
  data.expressions
  |> list.flat_map(fn(expr) {
    case expr {
      glance.Panic(location, _) -> [
        RuleResult(
          rule: "test_panic",
          location: location,
          message: "found panic",
        ),
      ]
      _ -> []
    }
  })
}

/// A dummy rule that flags every Panic expression
fn panic_rule() -> rule.V2Rule {
  V2Rule(
    name: "test_panic",
    default_severity: Error,
    needs_collect: True,
    check: check_for_panic,
  )
}

pub fn walk_finds_panic_in_function_test() {
  let results = test_helpers.lint_string("pub fn bad() { panic }", panic_rule())
  let assert True = list.length(results) == 1
}

pub fn walk_finds_nothing_in_clean_code_test() {
  let results = test_helpers.lint_string("pub fn good() { 1 }", panic_rule())
  let assert True = results == []
}

pub fn walk_recurses_into_blocks_test() {
  let results =
    test_helpers.lint_string("pub fn bad() { { panic } }", panic_rule())
  let assert True = list.length(results) == 1
}

pub fn walk_recurses_into_case_branches_test() {
  let results =
    test_helpers.lint_string(
      "pub fn bad(x) { case x { _ -> panic } }",
      panic_rule(),
    )
  let assert True = list.length(results) == 1
}

pub fn walk_fills_in_file_field_test() {
  let results = test_helpers.lint_string("pub fn bad() { panic }", panic_rule())
  let assert [result] = results
  let assert True = result.file == "test.gleam"
}

pub fn walk_applies_rule_severity_override_test() {
  // Rule hardcodes Error in its check fn, but default_severity is Warning
  let overridden_rule = V2Rule(..panic_rule(), default_severity: Warning)
  let results =
    test_helpers.lint_string("pub fn bad() { panic }", overridden_rule)
  let assert [result] = results
  let assert True = result.severity == Warning
}
