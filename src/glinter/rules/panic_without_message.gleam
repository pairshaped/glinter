import glance
import gleam/option.{None}
import glinter/rule

pub fn rule() -> rule.Rule {
  rule.new(name: "panic_without_message")
  |> rule.with_simple_expression_visitor(visitor: check_expression)
  |> rule.to_module_rule()
}

fn check_expression(
  expression: glance.Expression,
  span: glance.Span,
) -> List(rule.RuleError) {
  case expression {
    glance.Panic(_, None) -> [
      rule.error(
        message: "Add a message to this panic describing why it should never happen",
        details: "Panic messages help with debugging when the unexpected occurs.",
        location: span,
      ),
    ]
    _ -> []
  }
}
