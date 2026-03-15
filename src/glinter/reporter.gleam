import gleam/bit_array
import gleam/int
import gleam/json
import gleam/list
import gleam/order
import gleam/string
import glinter/rule.{type LintResult, type Severity}

pub type Format {
  Text
  Json
}

pub type Stats {
  Stats(file_count: Int, line_count: Int, elapsed_ms: Int)
}

/// Convert byte offset to line number (1-indexed)
pub fn byte_offset_to_line(source: String, offset: Int) -> Int {
  let source_bytes = <<source:utf8>>
  let size = bit_array.byte_size(source_bytes)
  let clamped = case offset <= size {
    True -> offset
    False -> size
  }
  case bit_array.slice(source_bytes, 0, clamped) {
    Ok(bytes) ->
      case bit_array.to_string(bytes) {
        Ok(s) ->
          s
          |> string.split("\n")
          |> list.length()
        Error(_) -> 1
      }
    Error(_) -> 1
  }
}

/// Sort results by file, then by line number
pub fn sort_results(
  results: List(LintResult),
  sources: List(#(String, String)),
) -> List(#(LintResult, Int)) {
  results
  |> list.map(fn(r) {
    let line = case list.find(sources, fn(s) { s.0 == r.file }) {
      Ok(#(_, source)) -> byte_offset_to_line(source, r.location.start)
      _ -> 0
    }
    #(r, line)
  })
  |> list.sort(fn(a, b) {
    case string.compare({ a.0 }.file, { b.0 }.file) {
      order.Eq -> int.compare(a.1, b.1)
      other -> other
    }
  })
}

pub fn format_text(
  results: List(LintResult),
  sources: List(#(String, String)),
  show_stats: Bool,
  stats: Stats,
) -> String {
  let sorted = sort_results(results, sources)
  let lines =
    sorted
    |> list.map(fn(pair) {
      let #(r, line) = pair
      r.file
      <> ":"
      <> int.to_string(line)
      <> ": ["
      <> severity_to_string(r.severity)
      <> "] "
      <> r.rule
      <> ": "
      <> r.message
    })

  let error_count =
    results |> list.filter(fn(r) { r.severity == rule.Error }) |> list.length()
  let warning_count =
    results
    |> list.filter(fn(r) { r.severity == rule.Warning })
    |> list.length()
  let total = list.length(results)

  let summary =
    "\nFound "
    <> int.to_string(total)
    <> " "
    <> pluralize(total, "issue", "issues")
    <> " ("
    <> int.to_string(error_count)
    <> " "
    <> pluralize(error_count, "error", "errors")
    <> ", "
    <> int.to_string(warning_count)
    <> " "
    <> pluralize(warning_count, "warning", "warnings")
    <> ")"

  let stats_line = case show_stats {
    True -> "\n" <> format_stats_text(stats)
    False -> ""
  }

  case lines {
    [] -> "No issues found." <> stats_line
    _ -> string.join(lines, "\n") <> "\n" <> summary <> stats_line
  }
}

pub fn format_json(
  results: List(LintResult),
  sources: List(#(String, String)),
  show_stats: Bool,
  stats: Stats,
) -> String {
  let sorted = sort_results(results, sources)
  let error_count =
    results |> list.filter(fn(r) { r.severity == rule.Error }) |> list.length()
  let warning_count =
    results
    |> list.filter(fn(r) { r.severity == rule.Warning })
    |> list.length()

  let result_objects =
    sorted
    |> list.map(fn(pair) {
      let #(r, line) = pair
      json.object([
        #("rule", json.string(r.rule)),
        #("severity", json.string(severity_to_string(r.severity))),
        #("file", json.string(r.file)),
        #("line", json.int(line)),
        #("message", json.string(r.message)),
      ])
    })

  let base = [
    #("results", json.array(result_objects, fn(x) { x })),
    #(
      "summary",
      json.object([
        #("total", json.int(list.length(results))),
        #("errors", json.int(error_count)),
        #("warnings", json.int(warning_count)),
      ]),
    ),
  ]

  let fields = case show_stats {
    True ->
      list.append(base, [
        #(
          "stats",
          json.object([
            #("files", json.int(stats.file_count)),
            #("lines", json.int(stats.line_count)),
            #("elapsed_ms", json.int(stats.elapsed_ms)),
          ]),
        ),
      ])
    False -> base
  }

  json.object(fields)
  |> json.to_string()
}

fn format_stats_text(stats: Stats) -> String {
  "Linted "
  <> format_number(stats.file_count)
  <> " "
  <> pluralize(stats.file_count, "file", "files")
  <> " ("
  <> format_number(stats.line_count)
  <> " "
  <> pluralize(stats.line_count, "line", "lines")
  <> ") in "
  <> int.to_string(stats.elapsed_ms)
  <> "ms"
}

fn format_number(n: Int) -> String {
  case n < 1000 {
    True -> int.to_string(n)
    False -> {
      let thousands = n / 1000
      let remainder = n % 1000
      int.to_string(thousands)
      <> ","
      <> string.pad_start(int.to_string(remainder), to: 3, with: "0")
    }
  }
}

fn severity_to_string(severity: Severity) -> String {
  case severity {
    rule.Error -> "error"
    rule.Warning -> "warning"
  }
}

fn pluralize(count: Int, singular: String, plural: String) -> String {
  case count {
    1 -> singular
    _ -> plural
  }
}
