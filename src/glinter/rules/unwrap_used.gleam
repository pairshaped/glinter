import glance
import glinter/rule

pub fn rule() -> rule.Rule {
  rule.new(name: "unwrap_used")
  |> rule.with_simple_expression_visitor(visitor: check_expression)
  |> rule.to_module_rule()
}

fn check_expression(
  expression: glance.Expression,
  span: glance.Span,
) -> List(rule.RuleError) {
  case expression {
    glance.Call(
      _,
      glance.FieldAccess(_, glance.Variable(_, module_name), label),
      _,
    ) ->
      case module_name {
        "result" | "option" ->
          case label {
            "unwrap" | "lazy_unwrap" -> [
              rule.error(
                message: "Avoid "
                  <> module_name
                  <> "."
                  <> label
                  <> " — use a case expression to handle all variants",
                details: "Unwrap crashes on unexpected values. Pattern match instead.",
                location: span,
              ),
            ]
            _ -> []
          }
        _ -> []
      }
    _ -> []
  }
}
