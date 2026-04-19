import gleam/list
import gleam/string

pub type Scope {
  LineScope
  FunctionScope
  Stale
}

pub type Annotation {
  Annotation(
    rules: List(String),
    comment_line: Int,
    target_line: Int,
    scope: Scope,
    /// True when the nolint comment trails real code on the same line, e.g.
    /// `panic as "x" // nolint: avoid_panic`. Inline placement is disallowed
    /// because `gleam format` may move the comment off the line when wrapping,
    /// silently breaking the suppression. Inline annotations do NOT suppress;
    /// the runner emits a `nolint_inline` warning instead.
    inline: Bool,
  )
}

/// Parse source text for // nolint: comments and return annotations.
pub fn parse(source: String) -> List(Annotation) {
  let lines = string.split(source, "\n")
  parse_lines(lines, 1, [])
}

fn parse_lines(
  lines: List(String),
  line_num: Int,
  acc: List(Annotation),
) -> List(Annotation) {
  case lines {
    [] -> list.reverse(acc)
    [line, ..rest] -> {
      case extract_nolint(line) {
        Ok(rules) -> {
          let #(scope, target_line) = determine_scope(line, rest, line_num)
          let inline = is_inline(line)
          let annotation =
            Annotation(
              rules: rules,
              comment_line: line_num,
              target_line: target_line,
              scope: scope,
              inline: inline,
            )
          parse_lines(rest, line_num + 1, [annotation, ..acc])
        }
        Error(_) -> parse_lines(rest, line_num + 1, acc)
      }
    }
  }
}

/// Extract rule names from a line containing // nolint: or /// nolint:
fn extract_nolint(line: String) -> Result(List(String), Nil) {
  // Try /// nolint: first (doc comment), then // nolint: (regular comment)
  let after_prefix = case string.split(line, "/// nolint:") {
    [_, after, ..] -> Ok(after)
    _ ->
      case string.split(line, "// nolint:") {
        [_, after, ..] -> Ok(after)
        _ -> Error(Nil)
      }
  }
  case after_prefix {
    Ok(after) -> {
      // Strip reason (everything after --)
      let rules_part = case string.split(after, "--") {
        [before_reason, ..] -> before_reason
        _ -> after
      }
      let rules =
        rules_part
        |> string.split(",")
        |> list.map(string.trim)
        |> list.filter(fn(s) { s != "" })
      case rules {
        [] -> Error(Nil)
        _ -> Ok(rules)
      }
    }
    Error(_) -> Error(Nil)
  }
}

/// True when there's real code before the nolint comment on the same line.
pub fn is_inline(line: String) -> Bool {
  before_nolint(line) != ""
}

fn before_nolint(line: String) -> String {
  case string.split(line, "/// nolint:") {
    [prefix, _, ..] -> string.trim(prefix)
    _ ->
      case string.split(line, "// nolint:") {
        [prefix, _, ..] -> string.trim(prefix)
        _ -> ""
      }
  }
}

/// Determine scope based on whether the line is inline and what follows it.
fn determine_scope(
  current_line: String,
  remaining_lines: List(String),
  current_line_num: Int,
) -> #(Scope, Int) {
  case before_nolint(current_line) {
    "" -> classify_next_line(remaining_lines, current_line_num + 1)
    _ -> #(LineScope, current_line_num)
  }
}

/// Look at the next non-attribute line to determine scope.
/// Skips @attribute lines (e.g. @external, @deprecated) to find the fn.
/// next_line_num is the line number of the first line in `lines`.
fn classify_next_line(lines: List(String), next_line_num: Int) -> #(Scope, Int) {
  case lines {
    [] -> #(Stale, next_line_num - 1)
    [next_line, ..rest] -> {
      let trimmed = string.trim(next_line)
      case trimmed {
        "" -> #(Stale, next_line_num - 1)
        _ ->
          case
            string.starts_with(trimmed, "fn ")
            || string.starts_with(trimmed, "pub fn ")
          {
            True -> #(FunctionScope, next_line_num)
            False ->
              case string.starts_with(trimmed, "@") {
                // Skip attribute lines and keep looking
                True -> classify_next_line(rest, next_line_num + 1)
                False ->
                  case string.starts_with(trimmed, "///") {
                    // Skip doc comment lines and keep looking
                    True -> classify_next_line(rest, next_line_num + 1)
                    False ->
                      case string.starts_with(trimmed, "//") {
                        True -> #(Stale, next_line_num - 1)
                        False -> #(LineScope, next_line_num)
                      }
                  }
              }
          }
      }
    }
  }
}
