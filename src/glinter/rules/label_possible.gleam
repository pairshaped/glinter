import glance
import gleam/list
import gleam/option.{None, Some}
import glinter/rule

pub fn rule() -> rule.Rule {
  rule.new(name: "label_possible")
  |> rule.with_simple_function_visitor(visitor: check_function)
  |> rule.to_module_rule()
}

fn check_function(
  definition: glance.Definition(glance.Function),
  span: glance.Span,
) -> List(rule.RuleError) {
  let function = definition.definition
  let params = function.parameters

  // Suppression: @external functions (labels can't be used at FFI call sites)
  let is_external =
    list.any(definition.attributes, fn(attr) { attr.name == "external" })
  case is_external {
    True -> []
    False -> {
      // Suppression: private functions with <= 2 params (micro-helper ceremony)
      let is_private = function.publicity == glance.Private
      case is_private && list.length(params) <= 2 {
        True -> []
        False -> {
          // Suppression: any param is a function type (CPS/callback pattern)
          let has_callback_param =
            list.any(params, fn(param) {
              case param.type_ {
                Some(glance.FunctionType(..)) -> True
                _ -> False
              }
            })
          case has_callback_param {
            True -> []
            False -> check_params(params, span)
          }
        }
      }
    }
  }
}

fn check_params(
  params: List(glance.FunctionParameter),
  span: glance.Span,
) -> List(rule.RuleError) {
  // Skip functions with fewer than 2 params, or any unlabelled discard param
  // (you can't fully label a function that has an unlabelled discard)
  let has_unlabelled_discard =
    list.any(params, fn(param) {
      param.label == None
      && case param.name {
        glance.Discarded(_) -> True
        glance.Named(_) -> False
      }
    })
  case list.length(params) >= 2 && !has_unlabelled_discard {
    False -> []
    True ->
      params
      |> list.filter(fn(param) { param.label == None })
      |> list.map(fn(param) {
        let assert glance.Named(name) = param.name
        rule.error(
          message: "Parameter '"
            <> name
            <> "' could benefit from a label for clarity at call sites",
          details: "Labelled arguments make call sites self-documenting with zero performance cost.",
          location: span,
        )
      })
  }
}
