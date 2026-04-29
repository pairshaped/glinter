import glance
import glinter/helpers
import glinter/rule

type Context {
  /// True when the function has @external for all targets,
  /// meaning the Gleam body is an unreachable fallback.
  Context(in_external_fn: Bool)
}

pub fn rule() -> rule.Rule {
  rule.new_with_context(
    name: "discarded_result",
    initial: Context(in_external_fn: False),
  )
  |> rule.with_function_visitor(visitor: on_function)
  |> rule.with_statement_visitor(visitor: check_statement)
  |> rule.to_module_rule()
}

fn on_function(
  definition: glance.Definition(glance.Function),
  _span: glance.Span,
  _context: Context,
) -> #(List(rule.RuleError), Context) {
  #([], Context(in_external_fn: helpers.has_all_external_targets(definition)))
}

fn check_statement(
  statement: glance.Statement,
  context: Context,
) -> #(List(rule.RuleError), Context) {
  case context.in_external_fn {
    True -> #([], context)
    False ->
      case statement {
        glance.Assignment(
          location: location,
          kind: glance.Let,
          pattern: glance.PatternDiscard(_, ""),
          ..,
        ) -> #(
          [
            rule.error(
              message: "Result of this expression is being discarded: handle the error or use an explicit name",
              details: "Discarding results with `let _ = ...` hides potential errors. Handle the Result or use a named discard like `let _response = ...`.",
              location: location,
            ),
          ],
          context,
        )
        _ -> #([], context)
      }
  }
}
