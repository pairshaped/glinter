import glance
import gleam/option.{None}
import glinter/rule

pub fn rule() -> rule.Rule {
  rule.new(name: "redundant_case")
  |> rule.with_simple_expression_visitor(visitor: check_expression)
  |> rule.to_module_rule()
}

fn check_expression(
  expression: glance.Expression,
  span: glance.Span,
) -> List(rule.RuleError) {
  case expression {
    glance.Case(_, _, [glance.Clause(guard: None, ..)]) -> [
      rule.error(
        message: "Case expression has only one branch — use a let binding instead",
        details: "A single-branch case without a guard is equivalent to a let binding.",
        location: span,
      ),
    ]
    _ -> []
  }
}
