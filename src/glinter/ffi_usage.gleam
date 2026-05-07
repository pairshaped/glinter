import glance
import gleam/list
import gleam/string
import glinter/rule
import glinter/source
import simplifile

/// Patterns that indicate use of Gleam's private JS data API.
/// These internal representations can change between compiler versions.
const patterns = [
  #("$constructor", "Access to internal '$constructor' property"),
  #("makeError(", "Use of internal 'makeError' function"),
  #("CustomType", "Use of internal 'CustomType' base class"),
  #("isEqual(", "Use of internal 'isEqual' function"),
  #("remainderInt(", "Use of internal 'remainderInt' function"),
  #("divideInt(", "Use of internal 'divideInt' function"),
  #("divideFloat(", "Use of internal 'divideFloat' function"),
]

/// Check a single source string for FFI anti-patterns.
/// Returns LintResults with proper byte-offset locations.
pub fn check_source(
  file_path: String,
  source: String,
) -> List(rule.LintResult) {
  let lines = string.split(source, "\n")
  lines
  |> list.index_map(fn(line, index) {
    let line_number = index + 1
    let byte_offset = source.line_to_byte_offset(source, line_number)
    check_line(file_path, line, byte_offset)
  })
  |> list.flatten()
}

fn check_line(
  file_path: String,
  line: String,
  byte_offset: Int,
) -> List(rule.LintResult) {
  let pattern_results =
    patterns
    |> list.filter_map(fn(pattern) {
      let #(needle, message) = pattern
      case string.contains(line, needle) {
        True ->
          Ok(rule.LintResult(
            rule: "ffi_usage",
            severity: rule.Warning,
            file: file_path,
            location: glance.Span(start: byte_offset, end: byte_offset),
            message: message,
            details: "",
          ))
        False -> Error(Nil)
      }
    })

  let numeric_results = check_numeric_access(file_path, line, byte_offset)
  let import_results = check_gleam_import(file_path, line, byte_offset)

  list.flatten([pattern_results, numeric_results, import_results])
}

/// Check for numeric property access patterns: value[0], value.0
fn check_numeric_access(
  file_path: String,
  line: String,
  byte_offset: Int,
) -> List(rule.LintResult) {
  let has_bracket = has_bracket_numeric_access(line)
  let has_dot = has_dot_numeric_access(line)
  case has_bracket || has_dot {
    True -> [
      rule.LintResult(
        rule: "ffi_usage",
        severity: rule.Warning,
        file: file_path,
        location: glance.Span(start: byte_offset, end: byte_offset),
        message: "Numeric property access may rely on internal Gleam data representation",
        details: "",
      ),
    ]
    False -> []
  }
}

/// Check for bracket numeric access like value[0], value[1]
fn has_bracket_numeric_access(line: String) -> Bool {
  case string.split(line, "[") {
    [_] -> False
    parts ->
      list.any(list.drop(parts, 1), fn(after_bracket) {
        case string.split(after_bracket, "]") {
          [inside, ..] -> is_digits(string.trim(inside))
          _ -> False
        }
      })
  }
}

/// Check for dot numeric access like tuple.0, value.1
fn has_dot_numeric_access(line: String) -> Bool {
  case string.split(line, ".") {
    [_] -> False
    parts ->
      list.any(list.drop(parts, 1), fn(after_dot) {
        let trimmed = take_digits(after_dot)
        trimmed != ""
        && is_followed_by_boundary(after_dot, string.length(trimmed))
      })
  }
}

fn is_digit_char(c: String) -> Bool {
  case c {
    "0" | "1" | "2" | "3" | "4" | "5" | "6" | "7" | "8" | "9" -> True
    _ -> False
  }
}

/// Take leading digit characters from a string
fn take_digits(s: String) -> String {
  s
  |> string.to_graphemes()
  |> list.take_while(is_digit_char)
  |> string.concat()
}

/// Check that after the digits, the next char is a boundary (not a letter/digit)
/// This prevents matching things like "v2.0.1" version strings
fn is_followed_by_boundary(s: String, digit_count: Int) -> Bool {
  case string.drop_start(s, digit_count) {
    "" -> True
    rest ->
      case string.first(rest) {
        Ok(c) ->
          case c {
            ";" | ")" | "," | " " | "\t" | "]" | "}" | "\n" | "." -> True
            _ -> False
          }
        Error(_) -> True
      }
  }
}

fn is_digits(s: String) -> Bool {
  s != "" && s |> string.to_graphemes() |> list.all(is_digit_char)
}

/// Check for imports from gleam runtime (e.g. from "./gleam.mjs" or "../gleam.mjs")
fn check_gleam_import(
  file_path: String,
  line: String,
  byte_offset: Int,
) -> List(rule.LintResult) {
  case
    string.contains(line, "from")
    && string.contains(line, "gleam.mjs")
    && string.contains(line, "import")
  {
    True -> [
      rule.LintResult(
        rule: "ffi_usage",
        severity: rule.Warning,
        file: file_path,
        location: glance.Span(start: byte_offset, end: byte_offset),
        message: "Import from Gleam runtime internals — these APIs are not stable",
        details: "",
      ),
    ]
    False -> []
  }
}

/// Discover .mjs files in the given directories and lint them.
/// Returns both lint results and the source texts (needed by the reporter
/// to translate byte offsets back to line numbers).
pub fn check_ffi_files(
  directories: List(String),
  project_prefix: String,
) -> #(List(rule.LintResult), List(#(String, String))) {
  directories
  |> list.fold(#([], []), fn(acc, dir) {
    let #(results, sources) = acc
    let full_dir = project_prefix <> dir
    case simplifile.is_directory(full_dir) {
      Ok(True) ->
        case simplifile.get_files(full_dir) {
          Ok(files) ->
            files
            |> list.filter(fn(f) { string.ends_with(f, ".mjs") })
            |> list.fold(#(results, sources), fn(inner_acc, abs_path) {
              let #(inner_results, inner_sources) = inner_acc
              let display_path = source.strip_prefix(abs_path, project_prefix)
              case simplifile.read(abs_path) {
                Ok(source_text) -> #(
                  list.append(
                    inner_results,
                    check_source(display_path, source_text),
                  ),
                  [#(display_path, source_text), ..inner_sources],
                )
                Error(_) -> #(inner_results, inner_sources)
              }
            })
          Error(_) -> #(results, sources)
        }
      _ -> #(results, sources)
    }
  })
}
