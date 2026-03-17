import glance
import gleam/option.{None}
import glinter/rule

pub fn rule() -> rule.Rule {
  rule.new(name: "todo_without_message")
  |> rule.with_simple_expression_visitor(visitor: check_expression)
  |> rule.to_module_rule()
}

fn check_expression(
  expression: glance.Expression,
  span: glance.Span,
) -> List(rule.RuleError) {
  case expression {
    glance.Todo(_, None) -> [
      rule.error(
        message: "Add a message to this todo describing what needs to be done",
        details: "Todo messages document the intended implementation for future developers.",
        location: span,
      ),
    ]
    _ -> []
  }
}
