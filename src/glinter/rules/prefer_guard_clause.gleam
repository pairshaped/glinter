import glance
import gleam/option.{None, Some}
import glinter/rule.{type Rule, LintResult, Rule, Warning}

pub fn rule() -> Rule {
  Rule(
    name: "prefer_guard_clause",
    default_severity: Warning,
    check_expression: None,
    check_statement: None,
    check_function: Some(check),
    check_module: None,
  )
}

fn check(func: glance.Function) -> List(rule.LintResult) {
  case func.body {
    [glance.Expression(glance.Case(location, _, [clause_a, clause_b]))] ->
      case
        clause_a.guard == None
        && clause_b.guard == None
        && is_bool_pair(clause_a, clause_b)
        && has_simple_branch(clause_a, clause_b)
      {
        True -> [
          LintResult(
            rule: "prefer_guard_clause",
            severity: Warning,
            file: "",
            location: location,
            message: "Consider using 'use <- bool.guard' instead of case True/False",
          ),
        ]
        False -> []
      }
    _ -> []
  }
}

fn is_bool_pair(clause_a: glance.Clause, clause_b: glance.Clause) -> Bool {
  case clause_a.patterns, clause_b.patterns {
    [[glance.PatternVariant(_, None, "True", [], _)]],
      [[glance.PatternVariant(_, None, "False", [], _)]]
    -> True
    [[glance.PatternVariant(_, None, "False", [], _)]],
      [[glance.PatternVariant(_, None, "True", [], _)]]
    -> True
    _, _ -> False
  }
}

fn has_simple_branch(
  clause_a: glance.Clause,
  clause_b: glance.Clause,
) -> Bool {
  // At least one branch must be simple (not a Block)
  is_simple(clause_a.body) || is_simple(clause_b.body)
}

fn is_simple(expr: glance.Expression) -> Bool {
  case expr {
    glance.Block(_, _) -> False
    _ -> True
  }
}
