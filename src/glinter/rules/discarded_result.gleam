import glance
import gleam/option.{None, Some}
import glinter/rule.{type Rule, LintResult, Rule, Warning}

pub fn rule() -> Rule {
  Rule(
    name: "discarded_result",
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
      pattern: glance.PatternDiscard(_, ""),
      ..,
    ) -> [
      LintResult(
        rule: "discarded_result",
        severity: Warning,
        file: "",
        location: location,
        message: "Result of this expression is being discarded — handle the error or use an explicit name",
      ),
    ]
    _ -> []
  }
}
