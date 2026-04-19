import glance
import gleam/dict
import gleam/list
import glinter/config
import glinter/rule
import glinter/rules/avoid_panic
import glinter/runner

fn make_config() -> config.Config {
  config.Config(
    rules: dict.new(),
    ignore: dict.new(),
    include: ["src/"],
    exclude: [],
    stats: False,
    warnings_as_errors: False,
  )
}

fn run_with_source(
  source: String,
  rules: List(rule.Rule),
) -> List(rule.LintResult) {
  let assert Ok(module) = glance.module(source)
  let files = [#("test.gleam", source, module)]
  runner.run(rules: rules, files: files, config: make_config())
}

pub fn line_level_suppression_test() {
  let source = "pub fn bad() {\n  // nolint: avoid_panic\n  panic as \"ok\"\n}"
  let results = run_with_source(source, [avoid_panic.rule()])
  let panic_errors = results |> list.filter(fn(r) { r.rule == "avoid_panic" })
  let assert True = panic_errors == []
}

pub fn function_level_suppression_test() {
  let source =
    "// nolint: avoid_panic\npub fn fallback() {\n  panic as \"unreachable\"\n}"
  let results = run_with_source(source, [avoid_panic.rule()])
  let panic_errors = results |> list.filter(fn(r) { r.rule == "avoid_panic" })
  let assert True = panic_errors == []
}

pub fn unrelated_rule_not_suppressed_test() {
  let source =
    "// nolint: deep_nesting\npub fn bad() {\n  panic as \"oh no\"\n}"
  let results = run_with_source(source, [avoid_panic.rule()])
  let panic_errors = results |> list.filter(fn(r) { r.rule == "avoid_panic" })
  let assert True = list.length(panic_errors) == 1
}

pub fn stale_annotation_produces_warning_test() {
  let source = "// nolint: avoid_panic\n\npub fn good() { 1 }"
  let results = run_with_source(source, [avoid_panic.rule()])
  let nolint_warnings =
    results |> list.filter(fn(r) { r.rule == "nolint_unused" })
  let assert True = list.length(nolint_warnings) == 1
}

pub fn unused_annotation_produces_warning_test() {
  let source = "// nolint: avoid_panic\npub fn good() { 1 }"
  let results = run_with_source(source, [avoid_panic.rule()])
  let nolint_warnings =
    results |> list.filter(fn(r) { r.rule == "nolint_unused" })
  let assert True = list.length(nolint_warnings) == 1
}

pub fn inline_same_line_suppression_test() {
  let source = "pub fn x() {\n  panic as \"ok\" // nolint: avoid_panic\n}"
  let results = run_with_source(source, [avoid_panic.rule()])
  let panic_errors = results |> list.filter(fn(r) { r.rule == "avoid_panic" })
  let assert True = panic_errors == []
}

pub fn one_used_one_unused_annotation_test() {
  let source =
    "// nolint: avoid_panic\npub fn a() {\n  panic as \"ok\"\n}\n// nolint: avoid_panic\npub fn b() { 1 }"
  let results = run_with_source(source, [avoid_panic.rule()])
  let panic_errors = results |> list.filter(fn(r) { r.rule == "avoid_panic" })
  let unused = results |> list.filter(fn(r) { r.rule == "nolint_unused" })
  let assert True = panic_errors == []
  let assert True = list.length(unused) == 1
}

pub fn typo_in_rule_name_not_suppressed_test() {
  let source = "// nolint: avod_panic\npub fn bad() {\n  panic as \"oops\"\n}"
  let results = run_with_source(source, [avoid_panic.rule()])
  let panic_errors = results |> list.filter(fn(r) { r.rule == "avoid_panic" })
  let unused = results |> list.filter(fn(r) { r.rule == "nolint_unused" })
  let assert True = list.length(panic_errors) == 1
  let assert True = list.length(unused) == 1
}

pub fn function_scope_targets_second_function_only_test() {
  let source =
    "pub fn first() {\n  panic as \"a\"\n}\n\n// nolint: avoid_panic\npub fn second() {\n  panic as \"b\"\n}"
  let results = run_with_source(source, [avoid_panic.rule()])
  let panic_errors = results |> list.filter(fn(r) { r.rule == "avoid_panic" })
  // First function's panic should NOT be suppressed, second should be
  let assert True = list.length(panic_errors) == 1
}

pub fn line_scope_unused_annotation_test() {
  let source = "pub fn ok() {\n  // nolint: avoid_panic\n  let x = 1\n}"
  let results = run_with_source(source, [avoid_panic.rule()])
  let unused = results |> list.filter(fn(r) { r.rule == "nolint_unused" })
  let assert True = list.length(unused) == 1
}

pub fn filter_annotations_suppresses_matching_result_test() {
  let source = "// nolint: unused_exports\npub fn helper() { 1 }"
  let assert Ok(module) = glance.module(source)
  let result =
    rule.LintResult(
      rule: "unused_exports",
      severity: rule.Warning,
      file: "src/app.gleam",
      location: glance.Span(start: 26, end: 50),
      message: "unused export",
      details: "",
    )
  let filtered = runner.filter_annotations([result], source, module)
  let assert True = filtered == []
}

pub fn filter_annotations_keeps_non_matching_result_test() {
  let source = "// nolint: deep_nesting\npub fn helper() { 1 }"
  let assert Ok(module) = glance.module(source)
  let result =
    rule.LintResult(
      rule: "unused_exports",
      severity: rule.Warning,
      file: "src/app.gleam",
      location: glance.Span(start: 24, end: 48),
      message: "unused export",
      details: "",
    )
  let filtered = runner.filter_annotations([result], source, module)
  let assert True = list.length(filtered) == 1
}

pub fn function_scope_through_external_attributes_test() {
  let source =
    "// nolint: avoid_panic\n@external(erlang, \"m\", \"f\")\n@external(javascript, \"m.mjs\", \"f\")\npub fn my_ffi() {\n  panic as \"unreachable\"\n}"
  let results = run_with_source(source, [avoid_panic.rule()])
  let panic_errors = results |> list.filter(fn(r) { r.rule == "avoid_panic" })
  let assert True = panic_errors == []
}

pub fn nolint_unused_has_proper_location_test() {
  let source = "// nolint: avoid_panic\npub fn good() { 1 }"
  let results = run_with_source(source, [avoid_panic.rule()])
  let unused = results |> list.filter(fn(r) { r.rule == "nolint_unused" })
  let assert True = list.length(unused) == 1
  let assert [warning] = unused
  // Location should point to line 1 (byte offset 0), not default 0
  let assert True = warning.location.start == 0
}
