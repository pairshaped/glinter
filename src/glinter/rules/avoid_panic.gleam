import glance
import gleam/list
import glinter/rule.{type Rule, Error, LintResult, Rule}

pub fn rule() -> Rule {
  Rule(name: "avoid_panic", default_severity: Error, needs_collect: True, check: check)
}

fn check(data: rule.ModuleData, _source: String) -> List(rule.LintResult) {
  data.expressions |> list.flat_map(check_expression)
}

fn check_expression(expr: glance.Expression) -> List(rule.LintResult) {
  case expr {
    glance.Panic(location, _) -> [
      LintResult(
        rule: "avoid_panic",
        severity: Error,
        file: "",
        location: location,
        message: "Use Result types instead of panic",
      ),
    ]
    _ -> []
  }
}
