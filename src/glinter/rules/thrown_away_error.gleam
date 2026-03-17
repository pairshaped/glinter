import glance
import gleam/list
import glinter/rule

pub fn rule() -> rule.Rule {
  rule.new(name: "thrown_away_error")
  |> rule.with_simple_expression_visitor(visitor: check_expression)
  |> rule.to_module_rule()
}

fn check_expression(
  expression: glance.Expression,
  _span: glance.Span,
) -> List(rule.RuleError) {
  case expression {
    glance.Case(_, _, clauses) -> clauses |> list.flat_map(check_clause)
    _ -> []
  }
}

fn check_clause(clause: glance.Clause) -> List(rule.RuleError) {
  clause.patterns
  |> list.flat_map(fn(pattern_group) {
    pattern_group |> list.flat_map(check_pattern)
  })
}

fn check_pattern(pattern: glance.Pattern) -> List(rule.RuleError) {
  case pattern {
    glance.PatternVariant(
      location: location,
      module: _,
      constructor: "Error",
      arguments: [glance.UnlabelledField(glance.PatternDiscard(_, _))],
      with_spread: _,
    ) -> [
      rule.error(
        message: "Error value is discarded — prefer propagating with result.try or use. If this is a boundary, log and handle the error. If the error is Nil, use Error(Nil) instead to make that explicit",
        details: "Discarding errors silently hides failures that may need attention.",
        location: location,
      ),
    ]
    _ -> []
  }
}
