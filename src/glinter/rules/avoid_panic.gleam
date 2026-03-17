import glance
import glinter/rule

pub fn rule() -> rule.Rule {
  rule.new(name: "avoid_panic")
  |> rule.with_default_severity(severity: rule.Error)
  |> rule.with_simple_expression_visitor(visitor: check_expression)
  |> rule.to_module_rule()
}

fn check_expression(
  expression: glance.Expression,
  span: glance.Span,
) -> List(rule.RuleError) {
  case expression {
    glance.Panic(..) -> [
      rule.error(
        message: "Use Result types instead of panic",
        details: "Panics crash the process. Handle errors with Result types instead.",
        location: span,
      ),
    ]
    _ -> []
  }
}
