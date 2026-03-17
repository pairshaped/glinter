import glance
import gleam/list
import glinter/rule.{type V2Rule, RuleResult, V2Rule, Warning}

pub fn rule() -> V2Rule {
  V2Rule(
    name: "thrown_away_error",
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
    glance.Case(_, _, clauses) -> clauses |> list.flat_map(check_clause)
    _ -> []
  }
}

fn check_clause(clause: glance.Clause) -> List(rule.RuleResult) {
  clause.patterns
  |> list.flat_map(fn(pattern_group) {
    pattern_group |> list.flat_map(check_pattern)
  })
}

fn check_pattern(pattern: glance.Pattern) -> List(rule.RuleResult) {
  case pattern {
    glance.PatternVariant(
      location: location,
      module: _,
      constructor: "Error",
      arguments: [glance.UnlabelledField(glance.PatternDiscard(_, _))],
      with_spread: _,
    ) -> [
      RuleResult(
        rule: "thrown_away_error",
        location: location,
        message: "Error value is discarded — prefer propagating with result.try or use. If this is a boundary, log and handle the error. If the error is Nil, use Error(Nil) instead to make that explicit",
      ),
    ]
    _ -> []
  }
}
