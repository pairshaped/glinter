import gleam/list
import glinter/annotation.{FunctionScope, LineScope, Stale}

pub fn parses_standalone_nolint_test() {
  let results = annotation.parse("// nolint: avoid_panic\npanic as \"x\"")
  let assert True = list.length(results) == 1
  let assert [a] = results
  let assert True = a.rules == ["avoid_panic"]
  let assert True = a.target_line == 2
  let assert True = a.scope == LineScope
}

pub fn parses_inline_nolint_test() {
  let results = annotation.parse("let _ = x // nolint: discarded_result")
  let assert True = list.length(results) == 1
  let assert [a] = results
  let assert True = a.rules == ["discarded_result"]
  let assert True = a.target_line == 1
  let assert True = a.scope == LineScope
}

pub fn parses_multiple_rules_test() {
  let results =
    annotation.parse(
      "// nolint: deep_nesting, function_complexity\nfn walk() { 1 }",
    )
  let assert True = list.length(results) == 1
  let assert [a] = results
  let assert True = a.rules == ["deep_nesting", "function_complexity"]
}

pub fn ignores_reason_after_dashes_test() {
  let results =
    annotation.parse(
      "// nolint: avoid_panic -- unreachable fallback\npanic as \"x\"",
    )
  let assert True = list.length(results) == 1
  let assert [a] = results
  let assert True = a.rules == ["avoid_panic"]
}

pub fn detects_function_scope_fn_test() {
  let results = annotation.parse("// nolint: deep_nesting\nfn walk(x) { x }")
  let assert True = list.length(results) == 1
  let assert [a] = results
  let assert True = a.scope == FunctionScope
  let assert True = a.target_line == 2
}

pub fn detects_function_scope_pub_fn_test() {
  let results =
    annotation.parse("// nolint: deep_nesting\npub fn walk(x) { x }")
  let assert True = list.length(results) == 1
  let assert [a] = results
  let assert True = a.scope == FunctionScope
  let assert True = a.target_line == 2
}

pub fn detects_line_scope_for_non_fn_test() {
  let results =
    annotation.parse("// nolint: thrown_away_error\nError(_) -> Ok([])")
  let assert True = list.length(results) == 1
  let assert [a] = results
  let assert True = a.scope == LineScope
  let assert True = a.target_line == 2
}

pub fn detects_stale_annotation_blank_line_test() {
  let results = annotation.parse("// nolint: avoid_panic\n\npanic")
  let assert True = list.length(results) == 1
  let assert [a] = results
  let assert True = a.scope == Stale
}

pub fn detects_stale_annotation_eof_test() {
  let results = annotation.parse("// nolint: avoid_panic")
  let assert True = list.length(results) == 1
  let assert [a] = results
  let assert True = a.scope == Stale
}

pub fn detects_stale_annotation_followed_by_comment_test() {
  let results =
    annotation.parse("// nolint: avoid_panic\n// some other comment\npanic")
  let assert True = list.length(results) == 1
  let assert [a] = results
  let assert True = a.scope == Stale
}

pub fn parses_multiple_annotations_in_file_test() {
  let source =
    "// nolint: avoid_panic\npanic as \"a\"\n// nolint: deep_nesting\nfn nested() { 1 }"
  let results = annotation.parse(source)
  let assert True = list.length(results) == 2
  let assert [a1, a2] = results
  let assert True = a1.rules == ["avoid_panic"]
  let assert True = a1.target_line == 2
  let assert True = a1.scope == LineScope
  let assert True = a2.rules == ["deep_nesting"]
  let assert True = a2.target_line == 4
  let assert True = a2.scope == FunctionScope
}

pub fn empty_rules_returns_no_annotation_test() {
  let results = annotation.parse("// nolint: ,,,\nlet x = 1")
  let assert True = results == []
}

pub fn only_reason_no_rules_returns_no_annotation_test() {
  let results = annotation.parse("// nolint: -- just a reason\nlet x = 1")
  let assert True = results == []
}

pub fn skips_external_attribute_to_find_fn_test() {
  let results =
    annotation.parse(
      "// nolint: avoid_panic\n@external(erlang, \"mod\", \"fn\")\npub fn my_ffi() { panic }",
    )
  let assert True = list.length(results) == 1
  let assert [a] = results
  let assert True = a.scope == FunctionScope
  let assert True = a.target_line == 3
  let assert True = a.comment_line == 1
}

pub fn skips_multiple_attributes_to_find_fn_test() {
  let results =
    annotation.parse(
      "// nolint: avoid_panic\n@external(erlang, \"m\", \"f\")\n@external(javascript, \"m.mjs\", \"f\")\npub fn my_ffi() { panic }",
    )
  let assert True = list.length(results) == 1
  let assert [a] = results
  let assert True = a.scope == FunctionScope
  let assert True = a.target_line == 4
}

pub fn tracks_comment_line_number_test() {
  let results =
    annotation.parse("some code\n// nolint: avoid_panic\npanic as \"x\"")
  let assert True = list.length(results) == 1
  let assert [a] = results
  let assert True = a.comment_line == 2
  let assert True = a.target_line == 3
}

pub fn no_annotations_returns_empty_test() {
  let results = annotation.parse("pub fn ok() { 1 }")
  let assert True = results == []
}

pub fn parses_doc_comment_nolint_test() {
  let results =
    annotation.parse(
      "/// nolint: stringly_typed_error -- wraps OTP catch\npub fn try_call() { 1 }",
    )
  let assert True = list.length(results) == 1
  let assert [a] = results
  let assert True = a.rules == ["stringly_typed_error"]
  let assert True = a.scope == FunctionScope
  let assert True = a.target_line == 2
}

pub fn doc_comment_nolint_with_other_doc_comments_test() {
  let results =
    annotation.parse(
      "/// Run the given function, catching any panic.\n/// nolint: stringly_typed_error -- wraps OTP catch\npub fn try_call() { 1 }",
    )
  let assert True = list.length(results) == 1
  let assert [a] = results
  let assert True = a.rules == ["stringly_typed_error"]
  let assert True = a.scope == FunctionScope
  let assert True = a.target_line == 3
}

pub fn doc_comment_nolint_skips_following_doc_comments_test() {
  let results =
    annotation.parse(
      "/// nolint: avoid_panic\n/// Some documentation.\npub fn my_fn() { 1 }",
    )
  let assert True = list.length(results) == 1
  let assert [a] = results
  let assert True = a.scope == FunctionScope
  let assert True = a.target_line == 3
}

pub fn doc_comment_nolint_with_attributes_test() {
  let results =
    annotation.parse(
      "/// nolint: avoid_panic\n/// Docs here.\n@external(erlang, \"mod\", \"fn\")\npub fn my_ffi() { panic }",
    )
  let assert True = list.length(results) == 1
  let assert [a] = results
  let assert True = a.scope == FunctionScope
  let assert True = a.target_line == 4
}
