import glance
import gleam/list
import glinter/rule.{type V2Rule, RuleResult, V2Rule, Warning}

pub fn rule() -> V2Rule {
  V2Rule(
    name: "unwrap_used",
    default_severity: Warning,
    needs_collect: True,
    check: check,
  )
}

fn check(data: rule.ModuleData, _source: String) -> List(rule.RuleResult) {
  data.expressions |> list.flat_map(check_expression)
}

fn check_expression(expr: glance.Expression) -> List(rule.RuleResult) {
  case expr {
    glance.Call(
      location,
      glance.FieldAccess(_, glance.Variable(_, module_name), label),
      _,
    ) ->
      case module_name {
        "result" | "option" ->
          case label {
            "unwrap" | "lazy_unwrap" -> [
              RuleResult(
                rule: "unwrap_used",
                location: location,
                message: "Avoid "
                  <> module_name
                  <> "."
                  <> label
                  <> " — use a case expression to handle all variants",
              ),
            ]
            _ -> []
          }
        _ -> []
      }
    _ -> []
  }
}
