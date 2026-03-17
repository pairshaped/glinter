import glance
import glinter/rule

pub fn rule() -> rule.Rule {
  rule.new(name: "avoid_todo")
  |> rule.with_default_severity(severity: rule.Error)
  |> rule.with_simple_expression_visitor(visitor: check_expression)
  |> rule.to_module_rule()
}

fn check_expression(
  expression: glance.Expression,
  span: glance.Span,
) -> List(rule.RuleError) {
  case expression {
    glance.Todo(..) -> [
      rule.error(
        message: "Implement this function instead of using todo",
        details: "Todo expressions crash at runtime. Implement the actual logic.",
        location: span,
      ),
    ]
    _ -> []
  }
}
