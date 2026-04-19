import glance
import gleam/list
import glinter/rule

type Context {
  // Track depth inside concatenation chains so only the root node analyzes
  Context(concat_depth: Int)
}

pub fn rule() -> rule.Rule {
  rule.new_with_context(
    name: "unnecessary_string_concatenation",
    initial: Context(concat_depth: 0),
  )
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
    glance.BinaryOperator(_, glance.Concatenate, _, _) -> {
      case context.concat_depth {
        // Root of a concat chain: flatten and analyze the whole chain
        0 -> {
          let segments = flatten_concat(expression)
          let errors = check_chain(segments, span)
          #(errors, Context(concat_depth: context.concat_depth + 1))
        }
        // Inside a chain: skip, the root already handled it
        _ -> #([], Context(concat_depth: context.concat_depth + 1))
      }
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
    glance.BinaryOperator(_, glance.Concatenate, _, _) -> #(
      [],
      Context(concat_depth: context.concat_depth - 1),
    )
    _ -> #([], context)
  }
}

/// Flatten a chain of <> operations into a list of leaf segments (left to right)
fn flatten_concat(expression: glance.Expression) -> List(glance.Expression) {
  case expression {
    glance.BinaryOperator(_, glance.Concatenate, left, right) ->
      list.append(flatten_concat(left), flatten_concat(right))
    other -> [other]
  }
}

/// Analyze a flattened concat chain
fn check_chain(
  segments: List(glance.Expression),
  span: glance.Span,
) -> List(rule.RuleError) {
  let has_non_literal =
    list.any(segments, fn(seg) {
      case seg {
        glance.String(_, _) -> False
        _ -> True
      }
    })

  // Empty string concat is always a no-op, even in mixed chains
  let empty_errors =
    segments
    |> list.filter(fn(seg) {
      case seg {
        glance.String(_, "") -> True
        _ -> False
      }
    })
    |> list.map(fn(_) {
      rule.error(
        message: "Concatenation with an empty string has no effect, remove it",
        details: "Empty string concatenation is a no-op and adds visual noise.",
        location: span,
      )
    })

  // Two adjacent literals can be merged, but only if the whole chain is literals
  // (mixed chains are intentional template building)
  // Filter out empty strings before checking adjacent literals
  // (they're already reported by the empty-string check above)
  let non_empty_segments =
    list.filter(segments, fn(seg) {
      case seg {
        glance.String(_, "") -> False
        _ -> True
      }
    })
  let literal_errors = case has_non_literal {
    True -> []
    False -> check_adjacent_literals(non_empty_segments, span)
  }

  list.append(empty_errors, literal_errors)
}

fn check_adjacent_literals(
  segments: List(glance.Expression),
  span: glance.Span,
) -> List(rule.RuleError) {
  case segments {
    [glance.String(_, _), glance.String(_, _), ..rest] -> [
      rule.error(
        message: "Concatenation of two string literals, combine them into one string",
        details: "Two adjacent string literals can be merged at write time.",
        location: span,
      ),
      ..check_adjacent_literals(rest, span)
    ]
    [_, ..rest] -> check_adjacent_literals(rest, span)
    [] -> []
  }
}
