import glance
import glinter/rule

pub fn rule() -> rule.Rule {
  rule.new(name: "string_inspect")
  |> rule.with_simple_expression_visitor(visitor: check_expression)
  |> rule.to_module_rule()
}

fn check_expression(
  expression: glance.Expression,
  span: glance.Span,
) -> List(rule.RuleError) {
  case expression {
    glance.FieldAccess(_, glance.Variable(_, "string"), "inspect") -> [
      rule.error(
        message: "Use of 'string.inspect' is discouraged outside of debugging",
        details: "string.inspect produces debug representations, not user-facing text.",
        location: span,
      ),
    ]
    _ -> []
  }
}
