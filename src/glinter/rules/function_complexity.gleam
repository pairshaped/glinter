import glance
import gleam/int
import glinter/analysis
import glinter/rule

const threshold = 10

pub fn rule() -> rule.Rule {
  rule.new(name: "function_complexity")
  |> rule.with_default_severity(severity: rule.Off)
  |> rule.with_simple_function_visitor(visitor: check_function)
  |> rule.to_module_rule()
}

fn check_function(
  function: glance.Function,
  span: glance.Span,
) -> List(rule.RuleError) {
  let count = analysis.count_branches(function.body)
  case count > threshold {
    True -> [
      rule.error(
        message: "Function '"
          <> function.name
          <> "' has a complexity of "
          <> int.to_string(count)
          <> ", consider splitting into smaller functions",
        details: "Complex functions are harder to test and maintain. Consider extracting helper functions.",
        location: span,
      ),
    ]
    False -> []
  }
}
