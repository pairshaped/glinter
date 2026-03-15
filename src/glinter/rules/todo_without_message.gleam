import glance
import gleam/list
import gleam/option.{None}
import glinter/rule.{type Rule, LintResult, Rule, Warning}

pub fn rule() -> Rule {
  Rule(name: "todo_without_message", default_severity: Warning, check: check)
}

fn check(data: rule.ModuleData, _source: String) -> List(rule.LintResult) {
  data.expressions |> list.flat_map(check_expression)
}

fn check_expression(expr: glance.Expression) -> List(rule.LintResult) {
  case expr {
    glance.Todo(location, None) -> [
      LintResult(
        rule: "todo_without_message",
        severity: Warning,
        file: "",
        location: location,
        message: "Add a message to this todo describing what needs to be done",
      ),
    ]
    _ -> []
  }
}
