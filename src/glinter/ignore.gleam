import gleam/dict.{type Dict}
import gleam/list
import gleam/string

pub fn is_file_excluded(file: String, exclude: List(String)) -> Bool {
  list.any(exclude, fn(pattern) { glob_matches(file, pattern) })
}

pub fn is_rule_ignored(
  file: String,
  rule_name: String,
  ignore: Dict(String, List(String)),
) -> Bool {
  ignore
  |> dict.to_list()
  |> list.any(fn(pair) {
    let #(pattern, rules) = pair
    glob_matches(file, pattern) && list.contains(rules, rule_name)
  })
}

fn glob_matches(path: String, pattern: String) -> Bool {
  // A pattern ending in "/" is shorthand for "/**" — match this
  // directory prefix and everything under it. Without this rewrite,
  // string.split("foo/bar/", "/") yields ["foo", "bar", ""] and the
  // trailing empty segment never matches a real path segment, making
  // directory-prefix patterns a silent no-op.
  let normalized_pattern = case string.ends_with(pattern, "/") {
    True -> pattern <> "**"
    False -> pattern
  }
  do_glob_match(string.split(path, "/"), string.split(normalized_pattern, "/"))
}

fn do_glob_match(path_parts: List(String), pattern_parts: List(String)) -> Bool {
  case path_parts, pattern_parts {
    [], [] -> True
    _, [] -> False
    [], [pat, ..rest] -> pat == "**" && do_glob_match([], rest)
    [_, ..path_rest], ["**", ..pattern_rest] ->
      do_glob_match(path_parts, pattern_rest)
      || do_glob_match(path_rest, pattern_parts)
    [path_seg, ..path_rest], [pat_seg, ..pattern_rest] ->
      segment_matches(path_seg, pat_seg)
      && do_glob_match(path_rest, pattern_rest)
  }
}

fn segment_matches(segment: String, pattern: String) -> Bool {
  case string.split(pattern, "*") {
    [only] -> segment == only
    [prefix, suffix] ->
      string.starts_with(segment, prefix) && string.ends_with(segment, suffix)
    _ -> False
  }
}
