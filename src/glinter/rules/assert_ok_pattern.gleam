import glance
import gleam/list
import glinter/rule.{type V2Rule, RuleResult, V2Rule, Warning}

pub fn rule() -> V2Rule {
  V2Rule(
    name: "assert_ok_pattern",
    default_severity: Warning,
    needs_collect: True,
    check: check,
  )
}

fn check(data: rule.ModuleData, _source: String) -> List(rule.RuleResult) {
  data.statements |> list.flat_map(check_statement)
}

fn check_statement(stmt: glance.Statement) -> List(rule.RuleResult) {
  case stmt {
    glance.Assignment(location: location, kind: glance.LetAssert(_), ..) -> [
      RuleResult(
        rule: "assert_ok_pattern",
        location: location,
        message: "let assert crashes on mismatch — handle the error with a case expression",
      ),
    ]
    _ -> []
  }
}
