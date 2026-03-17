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
