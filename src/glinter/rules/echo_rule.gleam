import glance
import glinter/rule

pub fn rule() -> rule.Rule {
  rule.new(name: "echo")
  |> rule.with_simple_expression_visitor(visitor: check_expression)
  |> rule.to_module_rule()
}

fn check_expression(
  expression: glance.Expression,
  span: glance.Span,
) -> List(rule.RuleError) {
  case expression {
    glance.Echo(..) -> [
      rule.error(
        message: "Remove debug echo statement",
        details: "Echo statements should not be committed to production code.",
        location: span,
      ),
    ]
    _ -> []
  }
}
