import glance
import gleam/list
import gleam/option.{None}
import glinter/rule.{type V2Rule, RuleResult, V2Rule, Warning}

pub fn rule() -> V2Rule {
  V2Rule(
    name: "panic_without_message",
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
    glance.Panic(location, None) -> [
      RuleResult(
        rule: "panic_without_message",
        location: location,
        message: "Add a message to this panic describing why it should never happen",
      ),
    ]
    _ -> []
  }
}
