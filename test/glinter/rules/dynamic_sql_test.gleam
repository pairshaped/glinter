import gleam/list
import glinter/rule
import glinter/rules/dynamic_sql
import glinter/test_helpers

pub fn detects_select_concatenation_test() {
  let results =
    test_helpers.lint_string(
      "pub fn bad(id) { \"SELECT * FROM users WHERE id = \" <> id }",
      dynamic_sql.rule(),
    )
  let assert True = list.length(results) == 1
  let assert [result] = results
  let assert True = result.rule == "dynamic_sql"
  let assert True = result.severity == rule.Off
}

pub fn detects_insert_concatenation_test() {
  let results =
    test_helpers.lint_string(
      "pub fn bad(table) { \"INSERT INTO \" <> table <> \" VALUES (1)\" }",
      dynamic_sql.rule(),
    )
  let assert True = list.length(results) >= 1
}

pub fn detects_delete_concatenation_test() {
  let results =
    test_helpers.lint_string(
      "pub fn bad(id) { \"DELETE FROM users WHERE id = \" <> id }",
      dynamic_sql.rule(),
    )
  let assert True = list.length(results) == 1
}

pub fn detects_update_concatenation_test() {
  let results =
    test_helpers.lint_string(
      "pub fn bad(name) { \"UPDATE users SET name = \" <> name }",
      dynamic_sql.rule(),
    )
  let assert True = list.length(results) == 1
}

pub fn detects_drop_concatenation_test() {
  let results =
    test_helpers.lint_string(
      "pub fn bad(table) { \"DROP TABLE \" <> table }",
      dynamic_sql.rule(),
    )
  let assert True = list.length(results) == 1
}

pub fn ignores_normal_concatenation_test() {
  let results =
    test_helpers.lint_string(
      "pub fn good(name) { \"Hello, \" <> name }",
      dynamic_sql.rule(),
    )
  let assert True = results == []
}

pub fn ignores_non_concatenation_sql_test() {
  let results =
    test_helpers.lint_string(
      "pub fn good() { \"SELECT * FROM users\" }",
      dynamic_sql.rule(),
    )
  let assert True = results == []
}

pub fn detects_case_insensitive_test() {
  let results =
    test_helpers.lint_string(
      "pub fn bad(id) { \"select * from users where id = \" <> id }",
      dynamic_sql.rule(),
    )
  let assert True = list.length(results) == 1
}

pub fn detects_where_concatenation_test() {
  let results =
    test_helpers.lint_string(
      "pub fn bad(clause) { query <> \" WHERE \" <> clause }",
      dynamic_sql.rule(),
    )
  let assert True = list.length(results) == 1
}
