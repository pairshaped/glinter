import glance
import gleam/list
import gleam/option.{Some}
import glinter/rule

type Context {
  Context(in_external_type_match: Bool)
}

pub fn rule() -> rule.Rule {
  rule.new_with_context(
    name: "avoid_panic",
    initial: Context(in_external_type_match: False),
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
    // When entering a case expression, check if any clause pattern uses
    // a qualified constructor (module.Constructor) — this indicates matching
    // on an external type whose variants we don't control.
    glance.Case(_, _, clauses) -> {
      let has_external_patterns =
        list.any(clauses, fn(clause) {
          list.any(clause.patterns, fn(pattern_group) {
            list.any(pattern_group, has_qualified_constructor)
          })
        })
      #([], Context(in_external_type_match: has_external_patterns))
    }

    // Panic inside an external type match is allowed — you're forced
    // to handle variants from a type you don't control.
    glance.Panic(..) if context.in_external_type_match -> #([], context)

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
    glance.Case(..) -> #([], Context(in_external_type_match: False))
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
