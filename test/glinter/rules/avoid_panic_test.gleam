import gleam/list
import glinter/rule
import glinter/rules/avoid_panic
import glinter/test_helpers

pub fn detects_panic_test() {
  let results =
    test_helpers.lint_string_rule("pub fn bad() { panic }", avoid_panic.rule())
  let assert True = list.length(results) == 1
  let assert [result] = results
  let assert True = result.rule == "avoid_panic"
  let assert True = result.severity == rule.Error
}

pub fn detects_panic_with_message_test() {
  let results =
    test_helpers.lint_string_rule(
      "pub fn bad() { panic as \"oh no\" }",
      avoid_panic.rule(),
    )
  let assert True = list.length(results) == 1
}

pub fn ignores_clean_code_test() {
  let results =
    test_helpers.lint_string_rule("pub fn good() { Ok(1) }", avoid_panic.rule())
  let assert True = results == []
}

pub fn detects_nested_panic_test() {
  let results =
    test_helpers.lint_string_rule(
      "pub fn bad() { { panic } }",
      avoid_panic.rule(),
    )
  let assert True = list.length(results) == 1
}

pub fn allows_panic_in_external_type_exhaustive_match_test() {
  let results =
    test_helpers.lint_string_rule(
      "import external/lib
pub fn convert(value: lib.Param) -> Int {
  case value {
    lib.Supported(v) -> v
    lib.Unsupported(_) -> panic as \"not supported\"
  }
}",
      avoid_panic.rule(),
    )
  let assert True = results == []
}

pub fn allows_panic_after_nested_case_in_external_match_test() {
  let results =
    test_helpers.lint_string_rule(
      "import external/lib
pub fn convert(value: lib.Param) -> Int {
  case value {
    lib.Supported(v) -> {
      case v > 0 {
        True -> v
        False -> 0
      }
      panic as \"unreachable after inner case\"
    }
    lib.Unsupported(_) -> panic as \"not supported\"
  }
}",
      avoid_panic.rule(),
    )
  let assert True = results == []
}

pub fn still_flags_panic_in_own_module_match_test() {
  let results =
    test_helpers.lint_string_rule(
      "type MyType { A  B }
pub fn bad(value: MyType) -> Int {
  case value {
    A -> 1
    B -> panic as \"shouldn't happen\"
  }
}",
      avoid_panic.rule(),
    )
  let assert True = list.length(results) == 1
}
