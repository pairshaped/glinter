import glance
import gleam/list
import gleam/option.{None, Some}
import glinter/rule.{type Rule, LintResult, Rule, Warning}

pub fn rule() -> Rule {
  Rule(name: "redundant_case", default_severity: Warning, check: check)
}

fn check(data: rule.ModuleData, _source: String) -> List(rule.LintResult) {
  data.expressions |> list.flat_map(check_expression)
}

fn check_expression(expr: glance.Expression) -> List(rule.LintResult) {
  case expr {
    glance.Case(location, _, clauses) ->
      case clauses {
        [clause] ->
          case clause.guard {
            None -> [
              LintResult(
                rule: "redundant_case",
                severity: Warning,
                file: "",
                location: location,
                message: "Case expression has only one branch — use a let binding instead",
              ),
            ]
            Some(_) -> []
          }
        _ -> []
      }
    _ -> []
  }
}
