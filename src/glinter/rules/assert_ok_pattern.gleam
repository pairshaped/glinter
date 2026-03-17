import glance
import glinter/rule

pub fn rule() -> rule.Rule {
  rule.new(name: "assert_ok_pattern")
  |> rule.with_simple_statement_visitor(visitor: check_statement)
  |> rule.to_module_rule()
}

fn check_statement(statement: glance.Statement) -> List(rule.RuleError) {
  case statement {
    glance.Assignment(location: location, kind: glance.LetAssert(_), ..) -> [
      rule.error(
        message: "let assert crashes on mismatch — handle the error with a case expression",
        details: "let assert panics when the pattern does not match. Use case to handle all variants safely.",
        location: location,
      ),
    ]
    _ -> []
  }
}
