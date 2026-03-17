import glance
import gleam/list
import glinter/rule.{type V2Rule, RuleResult, V2Rule, Warning}

pub fn rule() -> V2Rule {
  V2Rule(
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
    // result.map_error with fn(_) { ... } discards the original error.
    // Note: replace_error is NOT flagged — it's the correct tool for
    // upgrading Nil errors (from list.find, int.parse, etc.) into
    // domain errors. If you don't need the original error, replace_error
    // is the right choice.
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
        | glance.LabelledField(_, _, glance.Fn(_, [param], _, _)) ->
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
