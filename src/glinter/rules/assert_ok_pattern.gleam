import glance
import gleam/list
import glinter/rule.{type Rule, LintResult, Rule, Warning}

pub fn rule() -> Rule {
  Rule(name: "assert_ok_pattern", default_severity: Warning, check: check)
}

fn check(data: rule.ModuleData, _source: String) -> List(rule.LintResult) {
  data.statements |> list.flat_map(check_statement)
}

fn check_statement(stmt: glance.Statement) -> List(rule.LintResult) {
  case stmt {
    glance.Assignment(location: location, kind: glance.LetAssert(_), ..) -> [
      LintResult(
        rule: "assert_ok_pattern",
        severity: Warning,
        file: "",
        location: location,
        message: "let assert crashes on mismatch — handle the error with a case expression",
      ),
    ]
    _ -> []
  }
}
