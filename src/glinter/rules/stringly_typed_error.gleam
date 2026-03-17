import glance
import gleam/option.{Some}
import glinter/rule

pub fn rule() -> rule.Rule {
  rule.new(name: "stringly_typed_error")
  |> rule.with_simple_function_visitor(visitor: check_function)
  |> rule.to_module_rule()
}

fn check_function(
  function: glance.Function,
  span: glance.Span,
) -> List(rule.RuleError) {
  case function.return {
    Some(glance.NamedType(_, "Result", _, [_, error_type])) ->
      case is_string_type(error_type) {
        True -> [
          rule.error(
            message: "Function '"
              <> function.name
              <> "' uses String as error type: use a custom error type instead",
            details: "Custom error types are pattern-matchable and self-documenting. String errors lose structure.",
            location: span,
          ),
        ]
        False -> []
      }
    _ -> []
  }
}

fn is_string_type(t: glance.Type) -> Bool {
  case t {
    glance.NamedType(_, "String", _, []) -> True
    _ -> False
  }
}
