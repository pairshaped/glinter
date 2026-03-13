import glance
import gleam/option.{None, Some}
import gleam/string
import glinter/rule.{type Rule, LintResult, Rule, Warning}

pub fn rule() -> Rule {
  Rule(
    name: "short_variable_name",
    default_severity: Warning,
    check_expression: None,
    check_statement: Some(check),
    check_function: None,
    check_module: None,
  )
}

fn check(stmt: glance.Statement) -> List(rule.LintResult) {
  case stmt {
    glance.Assignment(
      location: location,
      kind: glance.Let,
      pattern: glance.PatternVariable(_, name),
      ..,
    ) ->
      case string.length(name) == 1 {
        True -> [
          LintResult(
            rule: "short_variable_name",
            severity: Warning,
            file: "",
            location: location,
            message: "Variable name '"
              <> name
              <> "' is too short — use a descriptive name",
          ),
        ]
        False -> []
      }
    _ -> []
  }
}
