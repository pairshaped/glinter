import glance
import gleam/list
import gleam/option.{None}
import glinter/rule.{type V2Rule, RuleResult, V2Rule, Warning}

pub fn rule() -> V2Rule {
  V2Rule(
    name: "prefer_guard_clause",
    default_severity: Warning,
    needs_collect: False,
    check: check,
  )
}

fn check(data: rule.ModuleData, _source: String) -> List(rule.RuleResult) {
  data.module.functions
  |> list.flat_map(fn(def) { check_function(def.definition) })
}

fn check_function(func: glance.Function) -> List(rule.RuleResult) {
  case func.body {
    [glance.Expression(glance.Case(location, _, [clause_a, clause_b]))] ->
      case
        clause_a.guard == None
        && clause_b.guard == None
        && is_bool_pair(clause_a, clause_b)
        && has_simple_branch(clause_a, clause_b)
      {
        True -> [
          RuleResult(
            rule: "prefer_guard_clause",
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

fn has_simple_branch(clause_a: glance.Clause, clause_b: glance.Clause) -> Bool {
  is_simple(clause_a.body) || is_simple(clause_b.body)
}

fn is_simple(expr: glance.Expression) -> Bool {
  case expr {
    glance.Block(_, _) -> False
    _ -> True
  }
}
