import glance
import gleam/dict
import gleam/list
import glinter/config
import glinter/rule
import glinter/runner

fn make_rule(name: String, target_variable: String) -> rule.Rule {
  rule.new(name: name)
  |> rule.with_simple_expression_visitor(visitor: fn(expression, span) {
    case expression {
      glance.Variable(_, n) if n == target_variable -> [
        rule.error(
          message: "Found " <> target_variable,
          details: "",
          location: span,
        ),
      ]
      _ -> []
    }
  })
  |> rule.to_module_rule()
}

fn parse(source: String) -> glance.Module {
  let assert Ok(module) = glance.module(source)
  module
}

pub fn runner_collects_errors_from_multiple_rules_and_files_test() {
  let rule_a = make_rule("rule_a", "foo")
  let rule_b = make_rule("rule_b", "bar")

  let source1 = "pub fn main() { foo }"
  let source2 = "pub fn main() { bar }"

  let files = [
    #("file1.gleam", source1, parse(source1)),
    #("file2.gleam", source2, parse(source2)),
  ]

  let results =
    runner.run(rules: [rule_a, rule_b], files: files, config: config.default())

  // rule_a should find "foo" in file1, rule_b should find "bar" in file2
  let assert True =
    list.any(results, fn(r) { r.rule == "rule_a" && r.file == "file1.gleam" })
  let assert True =
    list.any(results, fn(r) { r.rule == "rule_b" && r.file == "file2.gleam" })

  // rule_a should NOT find "foo" in file2, rule_b should NOT find "bar" in file1
  let assert True =
    !list.any(results, fn(r) { r.rule == "rule_a" && r.file == "file2.gleam" })
  let assert True =
    !list.any(results, fn(r) { r.rule == "rule_b" && r.file == "file1.gleam" })
}

pub fn runner_both_rules_fire_on_same_file_test() {
  let rule_a = make_rule("rule_a", "foo")
  let rule_b = make_rule("rule_b", "bar")

  let source = "pub fn main() { foo\nbar }"
  let files = [#("test.gleam", source, parse(source))]

  let results =
    runner.run(rules: [rule_a, rule_b], files: files, config: config.default())

  let assert True = list.length(results) == 2
  let assert True = list.any(results, fn(r) { r.rule == "rule_a" })
  let assert True = list.any(results, fn(r) { r.rule == "rule_b" })
}

pub fn runner_empty_files_returns_empty_test() {
  let rule_a = make_rule("rule_a", "foo")

  let results = runner.run(rules: [rule_a], files: [], config: config.default())

  let assert True = list.is_empty(results)
}

pub fn runner_empty_rules_returns_empty_test() {
  let source = "pub fn main() { foo }"
  let files = [#("test.gleam", source, parse(source))]

  let results = runner.run(rules: [], files: files, config: config.default())

  let assert True = list.is_empty(results)
}

pub fn runner_respects_ignore_config_test() {
  let rule_a = make_rule("rule_a", "foo")

  let source = "pub fn main() { foo }"
  let files = [#("src/ignored.gleam", source, parse(source))]

  // Ignore rule_a for src/ignored.gleam
  let ignore =
    config.default().ignore
    |> dict.insert("src/ignored.gleam", ["rule_a"])

  let cfg = config.Config(..config.default(), ignore: ignore)

  let results = runner.run(rules: [rule_a], files: files, config: cfg)

  let assert True = list.is_empty(results)
}
