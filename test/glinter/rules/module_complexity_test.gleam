import gleam/int
import gleam/list
import gleam/string
import glinter/rule
import glinter/rules/module_complexity
import glinter/test_helpers

fn make_function_with_cases(name: String, count: Int) -> String {
  let cases =
    list.repeat("case x { _ -> 1 }", count)
    |> string.join("\n")
  "pub fn " <> name <> "(x) {\n" <> cases <> "\n}"
}

fn make_n_functions(count: Int, cases_each: Int) -> String {
  list.repeat(Nil, count)
  |> list.index_map(fn(_, idx) {
    make_function_with_cases("f" <> int.to_string(idx), cases_each)
  })
  |> string.join("\n\n")
}

pub fn ignores_module_at_threshold_test() {
  // 10 functions x 10 cases each = 100
  let source = make_n_functions(10, 10)
  let results = test_helpers.lint_string_rule(source, module_complexity.rule())
  let assert True = results == []
}

pub fn detects_module_over_threshold_test() {
  // 10 functions x 10 cases + 1 extra = 101
  let source =
    make_n_functions(10, 10) <> "\n\npub fn extra(x) { case x { _ -> 1 } }"
  let results = test_helpers.lint_string_rule(source, module_complexity.rule())
  let assert True = list.length(results) == 1
  let assert [result] = results
  let assert True = result.rule == "module_complexity"
  let assert True = result.severity == rule.Off
}

pub fn ignores_simple_module_test() {
  let results =
    test_helpers.lint_string_rule(
      "pub fn f() { 1 }\npub fn g() { 2 }",
      module_complexity.rule(),
    )
  let assert True = results == []
}
