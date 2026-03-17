import glance
import glinter/rule

pub fn rule() -> rule.Rule {
  rule.new(name: "unwrap_used")
  |> rule.with_simple_expression_visitor(visitor: check_expression)
  |> rule.with_default_severity(severity: rule.Off)
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
                  <> " — consider whether the error should be handled explicitly",
                details: "Unwrap silently replaces errors with a default value. If the error represents a real failure, handle it with case or propagate with result.try. If the default is intentional (optional config, end of fallback chain), unwrap may be appropriate.",
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
