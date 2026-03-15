import glance
import gleam/list
import glinter/rule.{type Rule, LintResult, Rule, Warning}

pub fn rule() -> Rule {
  Rule(name: "unwrap_used", default_severity: Warning, needs_collect: True, check: check)
}

fn check(data: rule.ModuleData, _source: String) -> List(rule.LintResult) {
  data.expressions |> list.flat_map(check_expression)
}

fn check_expression(expr: glance.Expression) -> List(rule.LintResult) {
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
              LintResult(
                rule: "unwrap_used",
                severity: Warning,
                file: "",
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
