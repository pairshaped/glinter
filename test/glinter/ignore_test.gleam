import gleam/dict
import glinter/ignore

pub fn matches_exact_file_test() {
  let ignores = dict.from_list([#("src/bad.gleam", ["avoid_panic"])])
  let assert True =
    ignore.is_rule_ignored("src/bad.gleam", "avoid_panic", ignores)
}

pub fn no_match_different_rule_test() {
  let ignores = dict.from_list([#("src/bad.gleam", ["avoid_panic"])])
  let assert False = ignore.is_rule_ignored("src/bad.gleam", "echo", ignores)
}

pub fn matches_star_glob_test() {
  let ignores = dict.from_list([#("src/legacy/*.gleam", ["avoid_panic"])])
  let assert True =
    ignore.is_rule_ignored("src/legacy/old.gleam", "avoid_panic", ignores)
}

pub fn star_glob_does_not_match_nested_test() {
  let ignores = dict.from_list([#("src/legacy/*.gleam", ["avoid_panic"])])
  let assert False =
    ignore.is_rule_ignored("src/legacy/deep/old.gleam", "avoid_panic", ignores)
}

pub fn matches_double_star_glob_test() {
  let ignores = dict.from_list([#("test/**/*.gleam", ["avoid_todo"])])
  let assert True =
    ignore.is_rule_ignored("test/unit/foo_test.gleam", "avoid_todo", ignores)
}

pub fn double_star_matches_deeply_nested_test() {
  let ignores = dict.from_list([#("test/**/*.gleam", ["avoid_todo"])])
  let assert True =
    ignore.is_rule_ignored("test/a/b/c/foo_test.gleam", "avoid_todo", ignores)
}

pub fn no_match_outside_pattern_test() {
  let ignores = dict.from_list([#("test/**/*.gleam", ["avoid_todo"])])
  let assert False =
    ignore.is_rule_ignored("src/foo.gleam", "avoid_todo", ignores)
}

pub fn empty_ignores_test() {
  let assert False =
    ignore.is_rule_ignored("src/foo.gleam", "avoid_panic", dict.new())
}

// --- is_file_excluded tests ---

pub fn excludes_exact_file_test() {
  let exclude = ["src/server/sql.gleam"]
  let assert True = ignore.is_file_excluded("src/server/sql.gleam", exclude)
}

pub fn excludes_glob_pattern_test() {
  let exclude = ["src/generated/**/*.gleam"]
  let assert True =
    ignore.is_file_excluded("src/generated/deep/file.gleam", exclude)
}

pub fn does_not_exclude_non_matching_test() {
  let exclude = ["src/generated/**/*.gleam"]
  let assert False = ignore.is_file_excluded("src/server/app.gleam", exclude)
}

pub fn empty_exclude_list_test() {
  let assert False = ignore.is_file_excluded("src/foo.gleam", [])
}

// A trailing slash in a pattern is shorthand for "/** " — match every
// file under this directory at any depth. Without this shorthand the
// split produces a trailing empty segment that never matches anything,
// so the pattern silently does nothing.
pub fn excludes_directory_prefix_shallow_test() {
  let exclude = ["src/generated/"]
  let assert True = ignore.is_file_excluded("src/generated/foo.gleam", exclude)
}

pub fn excludes_directory_prefix_deeply_nested_test() {
  let exclude = ["src/generated/"]
  let assert True =
    ignore.is_file_excluded(
      "src/generated/libero/admin/rpc/records.gleam",
      exclude,
    )
}

pub fn directory_prefix_does_not_match_sibling_substring_test() {
  // Prefix excludes must respect directory boundaries — "src/generated/"
  // should not accidentally match "src/generatedx.gleam".
  let exclude = ["src/generated/"]
  let assert False = ignore.is_file_excluded("src/generatedx.gleam", exclude)
}

pub fn directory_prefix_does_not_match_outside_tree_test() {
  let exclude = ["src/generated/"]
  let assert False = ignore.is_file_excluded("src/server/app.gleam", exclude)
}

pub fn directory_prefix_works_for_ignore_rules_test() {
  // The same trailing-slash shorthand applies to rule-ignore patterns,
  // because both codepaths go through glob_matches.
  let ignores =
    dict.from_list([#("src/generated/", ["avoid_panic", "label_possible"])])
  let assert True =
    ignore.is_rule_ignored(
      "src/generated/libero/rpc_dispatch.gleam",
      "avoid_panic",
      ignores,
    )
}
