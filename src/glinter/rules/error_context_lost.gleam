import glance
import gleam/list
import glinter/rule

pub fn rule() -> rule.Rule {
  rule.new(name: "error_context_lost")
  |> rule.with_simple_expression_visitor(visitor: check_expression)
  |> rule.to_module_rule()
}

fn check_expression(
  expression: glance.Expression,
  span: glance.Span,
) -> List(rule.RuleError) {
  case expression {
    // result.map_error with fn(_) { ... } discards the original error.
    // Note: replace_error is NOT flagged — it's the correct tool for
    // upgrading Nil errors (from list.find, int.parse, etc.) into
    // domain errors. If you don't need the original error, replace_error
    // is the right choice.
    glance.Call(
      _,
      glance.FieldAccess(_, glance.Variable(_, "result"), "map_error"),
      args,
    ) -> check_map_error_discard(span, args)
    _ -> []
  }
}

fn check_map_error_discard(
  location: glance.Span,
  args: List(glance.Field(glance.Expression)),
) -> List(rule.RuleError) {
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
      rule.error(
        message: "result.map_error discards the original error — consider wrapping it instead",
        details: "Discarding the original error loses context for debugging and error handling.",
        location: location,
      ),
    ]
    False -> []
  }
}
