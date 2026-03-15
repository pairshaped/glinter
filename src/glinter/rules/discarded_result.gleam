import glance
import gleam/list
import glinter/rule.{type Rule, LintResult, Rule, Warning}

pub fn rule() -> Rule {
  Rule(name: "discarded_result", default_severity: Warning, needs_collect: True, check: check)
}

fn check(data: rule.ModuleData, _source: String) -> List(rule.LintResult) {
  data.statements |> list.flat_map(check_statement)
}

fn check_statement(stmt: glance.Statement) -> List(rule.LintResult) {
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
