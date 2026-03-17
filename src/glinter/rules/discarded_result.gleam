import glance
import gleam/list
import glinter/rule.{type V2Rule, RuleResult, V2Rule, Warning}

pub fn rule() -> V2Rule {
  V2Rule(
    name: "discarded_result",
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
    glance.Assignment(
      location: location,
      kind: glance.Let,
      pattern: glance.PatternDiscard(_, ""),
      ..,
    ) -> [
      RuleResult(
        rule: "discarded_result",
        location: location,
        message: "Result of this expression is being discarded — handle the error or use an explicit name",
      ),
    ]
    _ -> []
  }
}
