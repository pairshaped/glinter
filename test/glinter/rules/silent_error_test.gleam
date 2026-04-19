/// Tests demonstrating the gap in error-flow tracking.
///
/// These tests document scenarios where a Result error is silently discarded
/// and no current rule catches it. They are written as "should catch but
/// currently doesn't" — the assertions verify the current (broken) behavior.
///
/// When we build error-flow tracking, flip these assertions to verify
/// the new rule catches the silent discards.
import glinter/rules/discarded_result
import glinter/rules/thrown_away_error
import glinter/test_helpers

/// Caller uses list.filter_map to silently drop errors from a function
/// that returns Result. No rule catches this.
pub fn filter_map_silently_drops_errors_test() {
  let source =
    "
    import gleam/list
    pub fn list_items(rows: List(Row)) -> List(Item) {
      list.filter_map(rows, fn(row) { item_from_row(row) })
    }
    "
  // discarded_result doesn't catch this
  let results = test_helpers.lint_string_rule(source, discarded_result.rule())
  let assert True = results == []

  // thrown_away_error doesn't catch this either
  let results2 = test_helpers.lint_string_rule(source, thrown_away_error.rule())
  let assert True = results2 == []
  // GAP: errors from item_from_row are silently dropped
}

/// Caller maps over Results and only keeps the Ok values, discarding errors.
/// No rule catches this.
pub fn ok_values_silently_drops_errors_test() {
  let source =
    "
    import gleam/result
    import gleam/list
    pub fn list_items(rows: List(Row)) -> List(Item) {
      rows
      |> list.map(fn(row) { item_from_row(row) })
      |> result.values()
    }
    "
  let results = test_helpers.lint_string_rule(source, discarded_result.rule())
  let assert True = results == []

  let results2 = test_helpers.lint_string_rule(source, thrown_away_error.rule())
  let assert True = results2 == []
  // GAP: errors from item_from_row are silently dropped
}

/// Caller uses result.unwrap to replace an error with a default,
/// hiding the failure. unwrap_used would catch this, but it's a
/// different concern — the question is whether the ERROR got reported,
/// not whether unwrap was used.
pub fn unwrap_hides_error_test() {
  let source =
    "
    import gleam/result
    pub fn get_status(row: Row) -> Status {
      status_from_string(row.status)
      |> result.unwrap(Default)
    }
    "
  let results = test_helpers.lint_string_rule(source, discarded_result.rule())
  let assert True = results == []

  let results2 = test_helpers.lint_string_rule(source, thrown_away_error.rule())
  let assert True = results2 == []
  // GAP: bad status silently replaced with Default, no logging
}
