import glance
import gleam/list
import glinter/rule.{type Rule, LintResult, Rule, Warning}

pub fn rule() -> Rule {
  Rule(name: "unnecessary_variable", default_severity: Warning, needs_collect: True, check: check)
}

fn check(data: rule.ModuleData, _source: String) -> List(rule.LintResult) {
  // Check function bodies directly
  let fn_results =
    data.module.functions
    |> list.flat_map(fn(def) { check_trailing_let(def.definition.body) })

  // Also check nested blocks and anonymous fns
  let nested_results =
    data.expressions |> list.flat_map(check_expression)

  list.append(fn_results, nested_results)
}

fn check_expression(expr: glance.Expression) -> List(rule.LintResult) {
  case expr {
    glance.Block(_, stmts) -> check_trailing_let(stmts)
    glance.Fn(_, _, _, body) -> check_trailing_let(body)
    _ -> []
  }
}

fn check_trailing_let(stmts: List(glance.Statement)) -> List(rule.LintResult) {
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
