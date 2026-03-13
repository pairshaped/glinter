import glance
import gleam/option.{None, Some}
import glinter/rule.{type Rule, Error, LintResult, Rule}

pub fn rule() -> Rule {
  Rule(
    name: "avoid_todo",
    default_severity: Error,
    check_expression: Some(check),
    check_statement: None,
    check_function: None,
    check_module: None,
  )
}

fn check(expr: glance.Expression) -> List(rule.LintResult) {
  case expr {
    glance.Todo(location, _) -> [
      LintResult(
        rule: "avoid_todo",
        severity: Error,
        file: "",
        location: location,
        message: "Implement this function instead of using todo",
      ),
    ]
    _ -> []
  }
}
