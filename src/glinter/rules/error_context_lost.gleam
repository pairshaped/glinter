import glance
import gleam/list
import glinter/rule.{type Rule, Rule, RuleResult, Warning}

pub fn rule() -> Rule {
  Rule(
    name: "error_context_lost",
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
    // result.replace_error always discards the original error
    glance.Call(
      location,
      glance.FieldAccess(_, glance.Variable(_, "result"), "replace_error"),
      _,
    ) -> [
      RuleResult(
        rule: "error_context_lost",
        location: location,
        message: "result.replace_error discards the original error — consider result.map_error to wrap it instead",
      ),
    ]
    // result.map_error with fn(_) { ... } discards the original error
    glance.Call(
      location,
      glance.FieldAccess(_, glance.Variable(_, "result"), "map_error"),
      args,
    ) -> check_map_error_discard(location, args)
    _ -> []
  }
}

fn check_map_error_discard(
  location: glance.Span,
  args: List(glance.Field(glance.Expression)),
) -> List(rule.RuleResult) {
  let has_discard =
    args
    |> list.any(fn(field) {
      case field {
        glance.UnlabelledField(glance.Fn(_, [param], _, _))
        | glance.LabelledField(_, _, glance.Fn(_, [param], _, _))
        ->
          case param.name {
            glance.Discarded(_) -> True
            _ -> False
          }
        _ -> False
      }
    })
  case has_discard {
    True -> [
      RuleResult(
        rule: "error_context_lost",
        location: location,
        message: "result.map_error discards the original error — consider wrapping it instead",
      ),
    ]
    False -> []
  }
}
