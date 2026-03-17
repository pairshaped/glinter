/// Count branching/control-flow nodes in an expression tree.
/// Used by function_complexity and module_complexity rules.
/// Expression traversal must stay in sync with rules/deep_nesting.gleam,
/// rules/missing_labels.gleam, and unused_exports.gleam when glance adds
/// new expression variants.
import glance.{type Expression, type Statement}
import gleam/list
import gleam/option.{None, Some}

/// Count branching/control-flow nodes in a statement list.
/// Counts: Case, Fn (anonymous), Block (nested).
pub fn count_branches(stmts: List(Statement)) -> Int {
  stmts
  |> list.fold(0, fn(acc, stmt) { acc + count_stmt_branches(stmt) })
}

fn count_stmt_branches(stmt: Statement) -> Int {
  case stmt {
    glance.Expression(expr) -> count_expr_branches(expr)
    glance.Assignment(value: expr, ..) -> count_expr_branches(expr)
    glance.Use(function: expr, ..) -> count_expr_branches(expr)
    glance.Assert(expression: expr, message: msg, ..) -> {
      let msg_count = case msg {
        Some(m) -> count_expr_branches(m)
        None -> 0
      }
      count_expr_branches(expr) + msg_count
    }
  }
}

fn count_expr_branches(expr: Expression) -> Int {
  case expr {
    glance.Case(_, subjects, clauses) -> {
      let subject_count =
        subjects
        |> list.fold(0, fn(acc, s) { acc + count_expr_branches(s) })
      let clause_count =
        clauses
        |> list.fold(0, fn(acc, clause) {
          acc + count_expr_branches(clause.body)
        })
      1 + subject_count + clause_count
    }

    glance.Fn(_, _, _, body) -> 1 + count_branches(body)

    glance.Block(_, stmts) -> 1 + count_branches(stmts)

    glance.Call(_, function, arguments) -> {
      let fn_count = count_expr_branches(function)
      let arg_count =
        arguments
        |> list.fold(0, fn(acc, field) {
          acc
          + case field {
            glance.LabelledField(_, _, item) -> count_expr_branches(item)
            glance.UnlabelledField(item) -> count_expr_branches(item)
            glance.ShorthandField(_, _) -> 0
          }
        })
      fn_count + arg_count
    }

    glance.BinaryOperator(_, _, left, right) ->
      count_expr_branches(left) + count_expr_branches(right)

    glance.Tuple(_, elements) ->
      elements
      |> list.fold(0, fn(acc, e) { acc + count_expr_branches(e) })

    glance.List(_, elements, rest) -> {
      let el_count =
        elements
        |> list.fold(0, fn(acc, e) { acc + count_expr_branches(e) })
      let rest_count = case rest {
        Some(r) -> count_expr_branches(r)
        None -> 0
      }
      el_count + rest_count
    }

    glance.FieldAccess(_, container, _) -> count_expr_branches(container)
    glance.TupleIndex(_, tuple, _) -> count_expr_branches(tuple)
    glance.NegateInt(_, inner) -> count_expr_branches(inner)
    glance.NegateBool(_, inner) -> count_expr_branches(inner)
    glance.Echo(_, Some(inner), _) -> count_expr_branches(inner)
    glance.Panic(_, Some(inner)) -> count_expr_branches(inner)
    glance.Todo(_, Some(inner)) -> count_expr_branches(inner)

    glance.RecordUpdate(_, _, _, _, fields) ->
      fields
      |> list.fold(0, fn(acc, field) {
        acc
        + case field.item {
          Some(e) -> count_expr_branches(e)
          None -> 0
        }
      })

    glance.FnCapture(_, _, function, args_before, args_after) -> {
      let walk_field = fn(acc, field) {
        acc
        + case field {
          glance.LabelledField(_, _, item) -> count_expr_branches(item)
          glance.UnlabelledField(item) -> count_expr_branches(item)
          glance.ShorthandField(_, _) -> 0
        }
      }
      count_expr_branches(function)
      + list.fold(args_before, 0, walk_field)
      + list.fold(args_after, 0, walk_field)
    }

    glance.BitString(_, segments) ->
      segments
      |> list.fold(0, fn(acc, seg) { acc + count_expr_branches(seg.0) })

    // Leaf nodes
    glance.Int(_, _)
    | glance.Float(_, _)
    | glance.String(_, _)
    | glance.Variable(_, _)
    | glance.Panic(_, None)
    | glance.Todo(_, None)
    | glance.Echo(_, None, _) -> 0
  }
}
