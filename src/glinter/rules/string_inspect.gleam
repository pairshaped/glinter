import glance
import gleam/list
import gleam/option.{None, Some}
import gleam/set.{type Set}
import glinter/rule

type Context {
  Context(allowed_vars: Set(String))
}

pub fn rule() -> rule.Rule {
  rule.new_with_context(
    name: "string_inspect",
    initial: Context(allowed_vars: set.new()),
  )
  |> rule.with_function_visitor(visitor: collect_generic_params)
  |> rule.with_expression_enter_visitor(visitor: check_expression)
  |> rule.to_module_rule()
}

fn collect_generic_params(
  function: glance.Function,
  _span: glance.Span,
  _context: Context,
) -> #(List(rule.RuleError), Context) {
  let generic_params =
    function.parameters
    |> list.filter_map(fn(param) {
      case param.type_ {
        Some(glance.VariableType(_, _)) ->
          case param.name {
            glance.Named(name) -> Ok(name)
            glance.Discarded(_) -> Error(Nil)
          }
        _ -> Error(Nil)
      }
    })
    |> set.from_list()
  #([], Context(allowed_vars: generic_params))
}

fn check_expression(
  expression: glance.Expression,
  span: glance.Span,
  context: Context,
) -> #(List(rule.RuleError), Context) {
  case expression {
    // Collect variables bound in Error(var) patterns from case clauses
    glance.Case(_, _, clauses) -> {
      let error_bound_vars =
        clauses
        |> list.flat_map(fn(clause) {
          clause.patterns
          |> list.flat_map(fn(pattern_group) {
            pattern_group
            |> list.filter_map(extract_error_bound_var)
          })
        })
        |> set.from_list()
      let new_allowed = set.union(context.allowed_vars, error_bound_vars)
      #([], Context(allowed_vars: new_allowed))
    }

    // Check string.inspect calls
    glance.Call(
      _,
      glance.FieldAccess(_, glance.Variable(_, "string"), "inspect"),
      [argument],
    ) -> {
      let arg_name = case argument {
        glance.UnlabelledField(glance.Variable(_, name)) -> Some(name)
        glance.LabelledField(_, _, glance.Variable(_, name)) -> Some(name)
        _ -> None
      }
      let is_allowed = case arg_name {
        Some(name) -> set.contains(context.allowed_vars, name)
        None -> False
      }
      case is_allowed {
        True -> #([], context)
        False -> #(
          [
            rule.error(
              message: "string.inspect produces debug output: use proper serialization for concrete types",
              details: "string.inspect is only appropriate for generic parameters or error values where no other serialization is available. For concrete types, implement a dedicated to_string or to_json function.",
              location: span,
            ),
          ],
          context,
        )
      }
    }

    _ -> #([], context)
  }
}

/// Extract the variable name from an Error(var) pattern.
fn extract_error_bound_var(pattern: glance.Pattern) -> Result(String, Nil) {
  case pattern {
    glance.PatternVariant(
      constructor: "Error",
      arguments: [glance.UnlabelledField(glance.PatternVariable(_, name))],
      ..,
    ) -> Ok(name)
    _ -> Error(Nil)
  }
}
