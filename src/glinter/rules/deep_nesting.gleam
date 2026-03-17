import glance
import gleam/int
import glinter/rule

const threshold = 5

type Context {
  Context(depth: Int)
}

pub fn rule() -> rule.Rule {
  rule.new_with_context(name: "deep_nesting", initial: Context(depth: 0))
  |> rule.with_function_visitor(visitor: on_function)
  |> rule.with_expression_enter_visitor(visitor: on_enter)
  |> rule.with_expression_exit_visitor(visitor: on_exit)
  |> rule.to_module_rule()
}

/// Reset depth to 1 for each top-level function body (the function body
/// itself counts as the first nesting level, matching V2 behaviour).
fn on_function(
  _function: glance.Function,
  _span: glance.Span,
  _context: Context,
) -> #(List(rule.RuleError), Context) {
  #([], Context(depth: 1))
}

fn on_enter(
  expression: glance.Expression,
  span: glance.Span,
  context: Context,
) -> #(List(rule.RuleError), Context) {
  case expression {
    glance.Block(..) | glance.Case(..) | glance.Fn(..) -> {
      let new_depth = context.depth + 1
      // Report only at the exact crossing point (threshold + 1), not deeper.
      // The v3 visitor always recurses into children, unlike the V2 version
      // which stops at the violation. This ensures one report per nesting chain.
      let errors = case new_depth == threshold + 1 {
        True -> [
          rule.error(
            message: "Nesting is "
              <> int.to_string(new_depth)
              <> " levels deep, flatten with use callbacks or extract a helper function",
            details: "Deeply nested code is hard to read. For nested case-on-Result chains, flatten with use callbacks (use value <- require_or_redirect(result, url)). For complex logic, extract inner blocks into named helper functions.",
            location: span,
          ),
        ]
        False -> []
      }
      #(errors, Context(depth: new_depth))
    }
    _ -> #([], context)
  }
}

fn on_exit(
  expression: glance.Expression,
  _span: glance.Span,
  context: Context,
) -> #(List(rule.RuleError), Context) {
  case expression {
    glance.Block(..) | glance.Case(..) | glance.Fn(..) -> #(
      [],
      Context(depth: context.depth - 1),
    )
    _ -> #([], context)
  }
}
