import glance
import glinter/rule

pub fn rule() -> rule.Rule {
  rule.new(name: "unnecessary_string_concatenation")
  |> rule.with_simple_expression_visitor(visitor: check_expression)
  |> rule.to_module_rule()
}

fn check_expression(
  expression: glance.Expression,
  span: glance.Span,
) -> List(rule.RuleError) {
  case expression {
    glance.BinaryOperator(_, glance.Concatenate, glance.String(_, ""), _)
    | glance.BinaryOperator(_, glance.Concatenate, _, glance.String(_, "")) -> [
      rule.error(
        message: "Concatenation with an empty string has no effect — remove it",
        details: "Empty string concatenation is a no-op and adds visual noise.",
        location: span,
      ),
    ]
    glance.BinaryOperator(
      _,
      glance.Concatenate,
      glance.String(_, _),
      glance.String(_, _),
    ) -> [
      rule.error(
        message: "Concatenation of two string literals — combine them into one string",
        details: "Two adjacent string literals can be merged at write time.",
        location: span,
      ),
    ]
    _ -> []
  }
}
