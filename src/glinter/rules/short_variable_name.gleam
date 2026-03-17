import glance
import gleam/string
import glinter/rule

pub fn rule() -> rule.Rule {
  rule.new(name: "short_variable_name")
  |> rule.with_simple_statement_visitor(visitor: check_statement)
  |> rule.to_module_rule()
}

fn check_statement(statement: glance.Statement) -> List(rule.RuleError) {
  case statement {
    glance.Assignment(
      location: location,
      kind: glance.Let,
      pattern: glance.PatternVariable(_, name),
      ..,
    ) ->
      case string.length(name) == 1 {
        True -> [
          rule.error(
            message: "Variable name '"
              <> name
              <> "' is too short — use a descriptive name",
            details: "Single-character variable names hurt readability. Use descriptive names.",
            location: location,
          ),
        ]
        False -> []
      }
    _ -> []
  }
}
