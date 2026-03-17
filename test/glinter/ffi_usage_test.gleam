import gleam/list
import glinter/ffi_usage

pub fn detects_numeric_property_access_test() {
  let results =
    ffi_usage.check_source("test.mjs", "let x = value[0];\nlet y = value[1];")
  let assert True = list.length(results) == 2
  let assert True = list.all(results, fn(r) { r.rule == "ffi_usage" })
}

pub fn detects_dot_numeric_access_test() {
  let results = ffi_usage.check_source("test.mjs", "return tuple.0;")
  let assert True = list.length(results) == 1
}

pub fn detects_dollar_constructor_test() {
  let results =
    ffi_usage.check_source("test.mjs", "if (value.$constructor === \"Ok\") {}")
  let assert True = list.length(results) == 1
}

pub fn detects_gleam_runtime_import_test() {
  let results =
    ffi_usage.check_source(
      "test.mjs",
      "import { toList, prepend } from \"./gleam.mjs\";",
    )
  let assert True = list.length(results) == 1
}

pub fn detects_make_error_test() {
  let results =
    ffi_usage.check_source("test.mjs", "let e = makeError(\"test\");")
  let assert True = list.length(results) == 1
}

pub fn detects_custom_type_usage_test() {
  let results =
    ffi_usage.check_source("test.mjs", "class Foo extends CustomType {}")
  let assert True = list.length(results) == 1
}

pub fn detects_is_equal_test() {
  let results = ffi_usage.check_source("test.mjs", "if (isEqual(a, b)) {}")
  let assert True = list.length(results) == 1
}

pub fn detects_remainder_int_test() {
  let results =
    ffi_usage.check_source("test.mjs", "let r = remainderInt(a, b);")
  let assert True = list.length(results) == 1
}

pub fn detects_divide_int_test() {
  let results = ffi_usage.check_source("test.mjs", "let d = divideInt(a, b);")
  let assert True = list.length(results) == 1
}

pub fn detects_divide_float_test() {
  let results = ffi_usage.check_source("test.mjs", "let d = divideFloat(a, b);")
  let assert True = list.length(results) == 1
}

pub fn ignores_clean_ffi_test() {
  let results =
    ffi_usage.check_source(
      "test.mjs",
      "export function now() {\n  return Date.now();\n}",
    )
  let assert True = results == []
}

pub fn detects_multiple_patterns_test() {
  let source =
    "import { toList } from \"./gleam.mjs\";\nlet x = value[0];\nif (v.$constructor) {}"
  let results = ffi_usage.check_source("test.mjs", source)
  let assert True = list.length(results) == 3
}

pub fn reports_correct_line_numbers_test() {
  let source = "// line 1\n// line 2\nlet x = value[0];"
  let results = ffi_usage.check_source("test.mjs", source)
  let assert [result] = results
  let assert True = result.location.start == 3
}
