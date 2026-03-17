import glance
import glinter/rule

pub fn rule() -> rule.Rule {
  rule.new(name: "discarded_result")
  |> rule.with_simple_statement_visitor(visitor: check_statement)
  |> rule.to_module_rule()
}

fn check_statement(statement: glance.Statement) -> List(rule.RuleError) {
  case statement {
    glance.Assignment(
      location: location,
      kind: glance.Let,
      pattern: glance.PatternDiscard(_, ""),
      ..,
    ) -> [
      rule.error(
        message: "Result of this expression is being discarded: handle the error or use an explicit name",
        details: "Discarding results with `let _ = ...` hides potential errors. Handle the Result or use a named discard like `let _response = ...`.",
        location: location,
      ),
    ]
    _ -> []
  }
}
