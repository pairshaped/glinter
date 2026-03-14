import glance
import gleam/option.{None, Some}
import glinter/rule.{type Rule, LintResult, Rule, Warning}

pub fn rule() -> Rule {
  Rule(
    name: "string_inspect",
    default_severity: Warning,
    check_expression: Some(check),
    check_statement: None,
    check_function: None,
    check_module: None,
  )
}

fn check(expr: glance.Expression) -> List(rule.LintResult) {
  case expr {
    glance.FieldAccess(location, glance.Variable(_, "string"), "inspect") -> [
      LintResult(
        rule: "string_inspect",
        severity: Warning,
        file: "",
        location: location,
        message: "Use of 'string.inspect' is discouraged outside of debugging",
      ),
    ]
    _ -> []
  }
}
