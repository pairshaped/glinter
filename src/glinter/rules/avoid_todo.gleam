import glance
import gleam/list
import glinter/rule.{type V2Rule, Error, RuleResult, V2Rule}

pub fn rule() -> V2Rule {
  V2Rule(
    name: "avoid_todo",
    default_severity: Error,
    needs_collect: True,
    check: check,
  )
}

fn check(data: rule.ModuleData, _source: String) -> List(rule.RuleResult) {
  data.expressions |> list.flat_map(check_expression)
}

fn check_expression(expr: glance.Expression) -> List(rule.RuleResult) {
  case expr {
    glance.Todo(location, _) -> [
      RuleResult(
        rule: "avoid_todo",
        location: location,
        message: "Implement this function instead of using todo",
      ),
    ]
    _ -> []
  }
}
