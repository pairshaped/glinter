import glance
import gleam/dict.{type Dict}
import gleam/int
import gleam/list
import gleam/option.{Some}
import glinter/rule

type Context {
  Context(signatures: Dict(String, List(glance.FunctionParameter)))
}

pub fn rule() -> rule.Rule {
  rule.module_rule_from_fn(
    name: "missing_labels",
    default_severity: rule.Warning,
    run: run,
  )
}

/// Pre-collect all function signatures, then run an expression visitor
/// that checks call sites against the full signature dict.
fn run(module: glance.Module, source: String) -> List(rule.RuleError) {
  // Phase 1: collect all function signatures up front
  let signatures =
    list.fold(module.functions, dict.new(), fn(acc, def) {
      dict.insert(acc, def.definition.name, def.definition.parameters)
    })

  // Phase 2: walk all expressions checking calls against signatures
  let schema =
    rule.new_with_context(
      name: "missing_labels",
      initial: Context(signatures: signatures),
    )
    |> rule.with_expression_enter_visitor(visitor: check_call)

  let #(errors, _context) =
    rule.visit_module(module: module, schema: schema, source: source)
  errors
}

fn check_call(
  expression: glance.Expression,
  span: glance.Span,
  context: Context,
) -> #(List(rule.RuleError), Context) {
  case expression {
    glance.Call(_, glance.Variable(_, name), arguments) ->
      case dict.get(context.signatures, name) {
        Ok(params) -> #(
          check_arguments(
            location: span,
            name: name,
            arguments: arguments,
            params: params,
          ),
          context,
        )
        Error(_) -> #([], context)
      }
    _ -> #([], context)
  }
}

fn check_arguments(
  location location: glance.Span,
  name name: String,
  arguments arguments: List(glance.Field(glance.Expression)),
  params params: List(glance.FunctionParameter),
) -> List(rule.RuleError) {
  case list.length(arguments) == list.length(params) {
    False -> []
    True ->
      list.zip(arguments, params)
      |> list.index_map(fn(pair, idx) {
        let #(arg, param) = pair
        case param.label, arg {
          Some(label), glance.UnlabelledField(_) ->
            Ok(rule.error(
              message: "Call to '"
                <> name
                <> "' is missing label '"
                <> label
                <> "' for argument "
                <> int.to_string(idx + 1),
              details: "Using labels makes function calls self-documenting and less error-prone.",
              location: location,
            ))
          _, _ -> Error(Nil)
        }
      })
      |> list.filter_map(fn(x) { x })
  }
}
