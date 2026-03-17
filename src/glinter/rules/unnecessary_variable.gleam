import glance
import gleam/list
import glinter/rule

pub fn rule() -> rule.Rule {
  rule.new(name: "unnecessary_variable")
  |> rule.with_simple_function_visitor(visitor: check_function)
  |> rule.with_simple_expression_visitor(visitor: check_expression)
  |> rule.to_module_rule()
}

fn check_function(
  function: glance.Function,
  _span: glance.Span,
) -> List(rule.RuleError) {
  check_trailing_let(function.body)
}

fn check_expression(
  expression: glance.Expression,
  _span: glance.Span,
) -> List(rule.RuleError) {
  case expression {
    glance.Block(_, stmts) -> check_trailing_let(stmts)
    glance.Fn(_, _, _, body) -> check_trailing_let(body)
    _ -> []
  }
}

fn check_trailing_let(stmts: List(glance.Statement)) -> List(rule.RuleError) {
  case list.reverse(stmts) {
    [
      glance.Expression(glance.Variable(_, var_name)),
      glance.Assignment(
        location: location,
        pattern: glance.PatternVariable(_, name),
        ..,
      ),
      ..
    ]
      if name == var_name
    -> [
      rule.error(
        message: "Variable '"
          <> name
          <> "' is immediately returned, just use the expression directly",
        details: "Assigning to a variable and immediately returning it adds unnecessary noise.",
        location: location,
      ),
    ]
    _ -> []
  }
}
