import glance
import gleam/list
import glinter/rule.{type V2Rule, RuleResult, V2Rule, Warning}

pub fn rule() -> V2Rule {
  V2Rule(
    name: "unnecessary_string_concatenation",
    default_severity: Warning,
    needs_collect: True,
    check: check,
  )
}

fn check(data: rule.ModuleData, _source: String) -> List(rule.RuleResult) {
  data.expressions |> list.flat_map(check_expression)
}

fn check_expression(expr: glance.Expression) -> List(rule.RuleResult) {
  case expr {
    glance.BinaryOperator(location, glance.Concatenate, glance.String(_, ""), _)
    | glance.BinaryOperator(
        location,
        glance.Concatenate,
        _,
        glance.String(_, ""),
      ) -> [
      RuleResult(
        rule: "unnecessary_string_concatenation",
        location: location,
        message: "Concatenation with an empty string has no effect — remove it",
      ),
    ]
    glance.BinaryOperator(
      location,
      glance.Concatenate,
      glance.String(_, _),
      glance.String(_, _),
    ) -> [
      RuleResult(
        rule: "unnecessary_string_concatenation",
        location: location,
        message: "Concatenation of two string literals — combine them into one string",
      ),
    ]
    _ -> []
  }
}
