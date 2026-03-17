import glance
import glinter/rule

pub fn rule() -> rule.Rule {
  rule.new(name: "division_by_zero")
  |> rule.with_default_severity(severity: rule.Error)
  |> rule.with_simple_expression_visitor(visitor: check_expression)
  |> rule.to_module_rule()
}

fn check_expression(
  expression: glance.Expression,
  span: glance.Span,
) -> List(rule.RuleError) {
  case expression {
    glance.BinaryOperator(_, operator, _, right) ->
      case is_division(operator) && is_zero(right) {
        True -> [
          rule.error(
            message: "Division by literal zero: Gleam returns 0 instead of crashing, which silently produces wrong results",
            details: "Gleam's division by literal zero returns 0 (not an error or crash). This is almost always a logic bug. Check the divisor or guard against zero before dividing.",
            location: span,
          ),
        ]
        False -> []
      }
    _ -> []
  }
}

fn is_division(operator: glance.BinaryOperator) -> Bool {
  case operator {
    glance.DivInt | glance.DivFloat | glance.RemainderInt -> True
    _ -> False
  }
}

fn is_zero(expression: glance.Expression) -> Bool {
  case expression {
    glance.Int(_, "0") -> True
    glance.Float(_, "0.0") -> True
    _ -> False
  }
}
