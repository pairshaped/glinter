import glance
import gleam/list
import gleam/option.{None, Some}
import glinter/rule.{type Rule, LintResult, Rule, Warning}

pub fn rule() -> Rule {
  Rule(
    name: "unnecessary_variable",
    default_severity: Warning,
    check_expression: Some(check_expression),
    check_statement: None,
    check_function: Some(check_function),
    check_module: None,
  )
}

fn check_function(func: glance.Function) -> List(rule.LintResult) {
  check_trailing_let(func.body)
}

fn check_expression(expr: glance.Expression) -> List(rule.LintResult) {
  case expr {
    glance.Block(_, stmts) -> check_trailing_let(stmts)
    glance.Fn(_, _, _, body) -> check_trailing_let(body)
    _ -> []
  }
}

fn check_trailing_let(
  stmts: List(glance.Statement),
) -> List(rule.LintResult) {
  case list.reverse(stmts) {
    [
      glance.Expression(glance.Variable(_, var_name)),
      glance.Assignment(
        location: location,
        pattern: glance.PatternVariable(_, name),
        ..
      ),
      ..
    ] if name == var_name -> [
      LintResult(
        rule: "unnecessary_variable",
        severity: Warning,
        file: "",
        location: location,
        message: "Variable '"
          <> name
          <> "' is immediately returned — just use the expression directly",
      ),
    ]
    _ -> []
  }
}
