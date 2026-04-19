import glance
import gleam/list
import gleam/option.{Some}
import glinter/rule

type Context {
  /// Depth counter for nested external-type case matches.
  /// 0 = not inside any external-type match.
  /// >0 = inside that many nested case expressions with external constructors.
  /// in_external_fn: True when the function has @external for all targets,
  /// meaning the Gleam body is an unreachable fallback.
  Context(external_match_depth: Int, in_external_fn: Bool)
}

pub fn rule() -> rule.Rule {
  rule.new_with_context(
    name: "avoid_panic",
    initial: Context(external_match_depth: 0, in_external_fn: False),
  )
  |> rule.with_default_severity(severity: rule.Error)
  |> rule.with_function_visitor(visitor: on_function)
  |> rule.with_expression_enter_visitor(visitor: on_enter)
  |> rule.with_expression_exit_visitor(visitor: on_exit)
  |> rule.to_module_rule()
}

fn on_function(
  definition: glance.Definition(glance.Function),
  _span: glance.Span,
  context: Context,
) -> #(List(rule.RuleError), Context) {
  #(
    [],
    Context(..context, in_external_fn: has_all_external_targets(definition)),
  )
}

fn on_enter(
  expression: glance.Expression,
  span: glance.Span,
  context: Context,
) -> #(List(rule.RuleError), Context) {
  case expression {
    glance.Case(_, _, clauses) -> {
      let has_external_patterns =
        list.any(clauses, fn(clause) {
          list.any(clause.patterns, fn(pattern_group) {
            list.any(pattern_group, has_qualified_constructor)
          })
        })
      let new_depth = case has_external_patterns {
        True -> context.external_match_depth + 1
        False -> context.external_match_depth
      }
      #([], Context(..context, external_match_depth: new_depth))
    }

    // Panic inside an external type match is allowed — you're forced
    // to handle variants from a type you don't control.
    glance.Panic(..) if context.external_match_depth > 0 -> #([], context)

    // Panic in an @external fallback body is allowed — the body is
    // unreachable when externals cover all compile targets.
    glance.Panic(..) if context.in_external_fn -> #([], context)

    glance.Panic(..) -> #(
      [
        rule.error(
          message: "Use Result types instead of panic",
          details: "Panics crash the process. Return Result and let the caller decide how to handle the error. If this panic is in an exhaustive match on an external type, consider wrapping the external interface.",
          location: span,
        ),
      ],
      context,
    )

    _ -> #([], context)
  }
}

fn on_exit(
  expression: glance.Expression,
  _span: glance.Span,
  context: Context,
) -> #(List(rule.RuleError), Context) {
  case expression {
    glance.Case(_, _, clauses) -> {
      let has_external_patterns =
        list.any(clauses, fn(clause) {
          list.any(clause.patterns, fn(pattern_group) {
            list.any(pattern_group, has_qualified_constructor)
          })
        })
      let new_depth = case has_external_patterns {
        True -> context.external_match_depth - 1
        False -> context.external_match_depth
      }
      #([], Context(..context, external_match_depth: new_depth))
    }
    _ -> #([], context)
  }
}

/// Check if a pattern uses a qualified constructor (e.g., module.Constructor).
fn has_qualified_constructor(pattern: glance.Pattern) -> Bool {
  case pattern {
    glance.PatternVariant(module: Some(_), ..) -> True
    _ -> False
  }
}

/// Check if a function has @external annotations covering all compile targets.
fn has_all_external_targets(
  definition: glance.Definition(glance.Function),
) -> Bool {
  let targets =
    definition.attributes
    |> list.filter_map(fn(attr) {
      case attr {
        glance.Attribute(
          name: "external",
          arguments: [glance.Variable(_, target), ..],
        ) -> Ok(target)
        _ -> Error(Nil)
      }
    })
  list.contains(targets, "erlang") && list.contains(targets, "javascript")
}
