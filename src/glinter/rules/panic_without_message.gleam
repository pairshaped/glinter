import glance
import gleam/list
import gleam/option.{None}
import glinter/rule.{type Rule, LintResult, Rule, Warning}

pub fn rule() -> Rule {
  Rule(name: "panic_without_message", default_severity: Warning, needs_collect: True, check: check)
}

fn check(data: rule.ModuleData, _source: String) -> List(rule.LintResult) {
  data.expressions |> list.flat_map(check_expression)
}

fn check_expression(expr: glance.Expression) -> List(rule.LintResult) {
  case expr {
    glance.Panic(location, None) -> [
      LintResult(
        rule: "panic_without_message",
        severity: Warning,
        file: "",
        location: location,
        message: "Add a message to this panic describing why it should never happen",
      ),
    ]
    _ -> []
  }
}
