import glance
import gleam/list
import gleam/string
import glinter/reporter
import glinter/rule.{LintResult}

fn make_result(rule: String, file: String, start: Int, message: String) {
  LintResult(
    rule: rule,
    severity: rule.Warning,
    file: file,
    location: glance.Span(start: start, end: start + 1),
    message: message,
    details: "",
  )
}

pub fn format_text_no_issues_test() {
  let stats = reporter.Stats(file_count: 3, line_count: 150, elapsed_ms: 42)
  let output = reporter.format_text([], [], False, stats)
  let assert True = output == "No issues found."
}

pub fn format_text_with_stats_test() {
  let stats = reporter.Stats(file_count: 3, line_count: 150, elapsed_ms: 42)
  let output = reporter.format_text([], [], True, stats)
  let assert True =
    string.contains(output, contain: "Linted 3 files (150 lines) in 42ms")
}

pub fn format_text_single_issue_test() {
  // Source: "pub fn main() {\n  1\n}" — 21 bytes.
  // Offset 16 falls on line 2 (the "  1" line).
  let results = [
    make_result("avoid_panic", "src/app.gleam", 16, "Use Result types"),
  ]
  let stats = reporter.Stats(file_count: 1, line_count: 10, elapsed_ms: 10)
  let output =
    reporter.format_text(results, [source("src/app.gleam")], False, stats)
  let assert True =
    string.contains(output, contain: "src/app.gleam:2:")
    && string.contains(
      output,
      contain: "[warning] avoid_panic: Use Result types",
    )
}

pub fn format_text_sorted_by_file_then_line_test() {
  let results = [
    make_result("echo", "src/b.gleam", 200, "Remove echo"),
    make_result("avoid_panic", "src/a.gleam", 100, "Use Result types"),
  ]
  let stats = reporter.Stats(file_count: 2, line_count: 20, elapsed_ms: 5)
  let output =
    reporter.format_text(
      results,
      [source("src/a.gleam"), source("src/b.gleam")],
      False,
      stats,
    )
  // a.gleam should come before b.gleam in the sorted output
  let lines = string.split(output, "\n")
  let file_lines =
    lines
    |> list.filter(fn(line) {
      string.contains(line, contain: "src/a.gleam:")
      || string.contains(line, contain: "src/b.gleam:")
    })
  let assert [first, second] = file_lines
  let assert True = string.contains(first, contain: "src/a.gleam:")
  let assert True = string.contains(second, contain: "src/b.gleam:")
}

pub fn format_text_pluralizes_correctly_test() {
  let results = [
    make_result("echo", "src/app.gleam", 0, "Remove echo"),
  ]
  let stats = reporter.Stats(file_count: 1, line_count: 5, elapsed_ms: 1)
  let output =
    reporter.format_text(results, [source("src/app.gleam")], False, stats)
  let assert True = string.contains(output, contain: "Found 1 issue")
}

pub fn format_text_multiple_issues_pluralizes_test() {
  let results = [
    make_result("echo", "src/a.gleam", 0, "Remove echo"),
    make_result("echo", "src/b.gleam", 0, "Remove echo"),
  ]
  let stats = reporter.Stats(file_count: 2, line_count: 10, elapsed_ms: 5)
  let output =
    reporter.format_text(
      results,
      [source("src/a.gleam"), source("src/b.gleam")],
      False,
      stats,
    )
  let assert True = string.contains(output, contain: "Found 2 issues")
}

pub fn format_json_single_result_test() {
  let results = [
    make_result("avoid_panic", "src/app.gleam", 16, "Use Result types"),
  ]
  let stats = reporter.Stats(file_count: 1, line_count: 10, elapsed_ms: 10)
  let output =
    reporter.format_json(results, [source("src/app.gleam")], False, stats)
  let assert True = string.contains(output, contain: "\"avoid_panic\"")
  let assert True = string.contains(output, contain: "\"src/app.gleam\"")
  let assert True = string.contains(output, contain: "\"results\"")
  let assert True = string.contains(output, contain: "\"summary\"")
}

pub fn format_text_uses_non_gleam_source_for_line_numbers_test() {
  let source_text = "// line 1\n// line 2\nlet x = value[0];"
  let results = [
    make_result(
      "ffi_usage",
      "src/bad.mjs",
      20,
      "Numeric property access may rely on internal Gleam data representation",
    ),
  ]
  let stats = reporter.Stats(file_count: 1, line_count: 3, elapsed_ms: 4)
  let output =
    reporter.format_text(results, [#("src/bad.mjs", source_text)], False, stats)
  let assert True = string.contains(output, contain: "src/bad.mjs:3:")
}

pub fn format_json_uses_non_gleam_source_for_line_numbers_test() {
  let source_text = "// line 1\n// line 2\nlet x = value[0];"
  let results = [
    make_result("ffi_usage", "src/bad.mjs", 20, "Numeric property access"),
  ]
  let stats = reporter.Stats(file_count: 1, line_count: 3, elapsed_ms: 4)
  let output =
    reporter.format_json(results, [#("src/bad.mjs", source_text)], False, stats)
  let assert True = string.contains(output, contain: "\"line\":3")
}

pub fn format_json_with_stats_test() {
  let results = [
    make_result("echo", "src/app.gleam", 0, "Remove echo"),
  ]
  let stats = reporter.Stats(file_count: 3, line_count: 150, elapsed_ms: 42)
  let output =
    reporter.format_json(results, [source("src/app.gleam")], True, stats)
  let assert True = string.contains(output, contain: "\"stats\"")
  let assert True = string.contains(output, contain: "\"files\"")
  let assert True = string.contains(output, contain: "\"elapsed_ms\"")
}

pub fn format_json_no_results_test() {
  let stats = reporter.Stats(file_count: 0, line_count: 0, elapsed_ms: 3)
  let output = reporter.format_json([], [], False, stats)
  let assert True = string.contains(output, contain: "\"results\"")
  let assert True = string.contains(output, contain: "\"total\"")
}

fn source(file: String) -> #(String, String) {
  #(file, "pub fn main() {\n  1\n}")
}
