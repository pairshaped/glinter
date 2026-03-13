import gleam/dict
import gleeunit/should
import glinter/ignore

pub fn matches_exact_file_test() {
  let ignores = dict.from_list([#("src/bad.gleam", ["avoid_panic"])])
  ignore.is_rule_ignored("src/bad.gleam", "avoid_panic", ignores)
  |> should.equal(True)
}

pub fn no_match_different_rule_test() {
  let ignores = dict.from_list([#("src/bad.gleam", ["avoid_panic"])])
  ignore.is_rule_ignored("src/bad.gleam", "echo", ignores)
  |> should.equal(False)
}

pub fn matches_star_glob_test() {
  let ignores = dict.from_list([#("src/legacy/*.gleam", ["avoid_panic"])])
  ignore.is_rule_ignored("src/legacy/old.gleam", "avoid_panic", ignores)
  |> should.equal(True)
}

pub fn star_glob_does_not_match_nested_test() {
  let ignores = dict.from_list([#("src/legacy/*.gleam", ["avoid_panic"])])
  ignore.is_rule_ignored("src/legacy/deep/old.gleam", "avoid_panic", ignores)
  |> should.equal(False)
}

pub fn matches_double_star_glob_test() {
  let ignores = dict.from_list([#("test/**/*.gleam", ["avoid_todo"])])
  ignore.is_rule_ignored("test/unit/foo_test.gleam", "avoid_todo", ignores)
  |> should.equal(True)
}

pub fn double_star_matches_deeply_nested_test() {
  let ignores = dict.from_list([#("test/**/*.gleam", ["avoid_todo"])])
  ignore.is_rule_ignored("test/a/b/c/foo_test.gleam", "avoid_todo", ignores)
  |> should.equal(True)
}

pub fn no_match_outside_pattern_test() {
  let ignores = dict.from_list([#("test/**/*.gleam", ["avoid_todo"])])
  ignore.is_rule_ignored("src/foo.gleam", "avoid_todo", ignores)
  |> should.equal(False)
}

pub fn empty_ignores_test() {
  ignore.is_rule_ignored("src/foo.gleam", "avoid_panic", dict.new())
  |> should.equal(False)
}
