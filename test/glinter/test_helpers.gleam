import glance
import gleam/list
import glinter/rule.{type LintResult, LintResult}
import glinter/walker

/// Parse source and lint with a single rule, returning results with
/// file and severity filled in (matching the orchestrator behaviour).
/// Respects needs_collect to catch rules that accidentally access
/// pre-collected data they did not request.
pub fn lint_string(
  source: String,
  r: rule.Rule,
) -> List(LintResult) {
  let assert Ok(module) = glance.module(source)
  let data = case r.needs_collect {
    True -> walker.collect(module)
    False -> walker.module_only(module)
  }
  r.check(data, source)
  |> list.map(fn(result) {
    LintResult(
      rule: result.rule,
      severity: r.default_severity,
      file: "test.gleam",
      location: result.location,
      message: result.message,
    )
  })
}
