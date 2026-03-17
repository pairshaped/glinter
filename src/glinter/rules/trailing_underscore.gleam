import glance
import gleam/string
import glinter/rule

pub fn rule() -> rule.Rule {
  rule.new(name: "trailing_underscore")
  |> rule.with_simple_function_visitor(visitor: check_function)
  |> rule.to_module_rule()
}

fn check_function(
  function: glance.Function,
  span: glance.Span,
) -> List(rule.RuleError) {
  case string.ends_with(function.name, "_") {
    True -> [
      rule.error(
        message: "Function '"
          <> function.name
          <> "' has a trailing underscore, remove it",
        details: "Trailing underscores on function names are unnecessary in Gleam.",
        location: span,
      ),
    ]
    False -> []
  }
}
