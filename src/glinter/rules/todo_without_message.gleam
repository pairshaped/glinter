import glance
import gleam/option.{None, Some}
import glinter/rule.{type Rule, LintResult, Rule, Warning}

pub fn rule() -> Rule {
  Rule(
    name: "todo_without_message",
    default_severity: Warning,
    check_expression: Some(check),
    check_statement: None,
    check_function: None,
    check_module: None,
  )
}

fn check(expr: glance.Expression) -> List(rule.LintResult) {
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
