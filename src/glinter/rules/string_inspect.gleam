import glance
import gleam/list
import glinter/rule.{type Rule, LintResult, Rule, Warning}

pub fn rule() -> Rule {
  Rule(name: "string_inspect", default_severity: Warning, check: check)
}

fn check(data: rule.ModuleData, _source: String) -> List(rule.LintResult) {
  data.expressions |> list.flat_map(check_expression)
}

fn check_expression(expr: glance.Expression) -> List(rule.LintResult) {
  case expr {
    glance.FieldAccess(location, glance.Variable(_, "string"), "inspect") -> [
      LintResult(
        rule: "string_inspect",
        severity: Warning,
        file: "",
        location: location,
        message: "Use of 'string.inspect' is discouraged outside of debugging",
      ),
    ]
    _ -> []
  }
}
