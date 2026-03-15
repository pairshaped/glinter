import glance
import gleam/list
import gleam/option.{None}
import glinter/rule.{type Rule, Rule, RuleResult, Warning}

pub fn rule() -> Rule {
  Rule(
    name: "redundant_case",
    default_severity: Warning,
    needs_collect: True,
    check: check,
  )
}

fn check(data: rule.ModuleData, _source: String) -> List(rule.RuleResult) {
  data.expressions |> list.flat_map(check_expression)
}

fn check_expression(expr: glance.Expression) -> List(rule.RuleResult) {
  case expr {
    glance.Case(location, _, [glance.Clause(guard: None, ..)]) -> [
      RuleResult(
        rule: "redundant_case",
        location: location,
        message: "Case expression has only one branch — use a let binding instead",
      ),
    ]
    _ -> []
  }
}
