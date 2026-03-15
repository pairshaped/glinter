import glance
import gleam/list
import glinter/rule.{type Rule, LintResult, Rule, Warning}

pub fn rule() -> Rule {
  Rule(name: "echo", default_severity: Warning, check: check)
}

fn check(data: rule.ModuleData, _source: String) -> List(rule.LintResult) {
  data.expressions |> list.flat_map(check_expression)
}

fn check_expression(expr: glance.Expression) -> List(rule.LintResult) {
  case expr {
    glance.Echo(location, _, _) -> [
      LintResult(
        rule: "echo",
        severity: Warning,
        file: "",
        location: location,
        message: "Remove debug echo statement",
      ),
    ]
    _ -> []
  }
}
