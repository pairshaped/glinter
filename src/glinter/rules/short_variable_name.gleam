import glance
import gleam/list
import gleam/string
import glinter/rule.{type V2Rule, RuleResult, V2Rule, Warning}

pub fn rule() -> V2Rule {
  V2Rule(
    name: "short_variable_name",
    default_severity: Warning,
    needs_collect: True,
    check: check,
  )
}

fn check(data: rule.ModuleData, _source: String) -> List(rule.RuleResult) {
  data.statements |> list.flat_map(check_statement)
}

fn check_statement(stmt: glance.Statement) -> List(rule.RuleResult) {
  case stmt {
    glance.Assignment(
      location: location,
      kind: glance.Let,
      pattern: glance.PatternVariable(_, name),
      ..,
    ) ->
      case string.length(name) == 1 {
        True -> [
          RuleResult(
            rule: "short_variable_name",
            location: location,
            message: "Variable name '"
              <> name
              <> "' is too short — use a descriptive name",
          ),
        ]
        False -> []
      }
    _ -> []
  }
}
