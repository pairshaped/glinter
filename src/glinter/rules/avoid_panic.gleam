import glance
import gleam/list
import gleam/option.{Some}
import glinter/rule

type Context {
  /// Depth counter for nested external-type case matches.
  /// 0 = not inside any external-type match.
  /// >0 = inside that many nested case expressions with external constructors.
  Context(external_match_depth: Int)
}

pub fn rule() -> rule.Rule {
  rule.new_with_context(
    name: "avoid_panic",
    initial: Context(external_match_depth: 0),
  )
  |> rule.with_default_severity(severity: rule.Error)
  |> rule.with_expression_enter_visitor(visitor: on_enter)
  |> rule.with_expression_exit_visitor(visitor: on_exit)
  |> rule.to_module_rule()
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
      #([], Context(external_match_depth: new_depth))
    }

    // Panic inside an external type match is allowed — you're forced
    // to handle variants from a type you don't control.
    glance.Panic(..) if context.external_match_depth > 0 -> #([], context)

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
      #([], Context(external_match_depth: new_depth))
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
