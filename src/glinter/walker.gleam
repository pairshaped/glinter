/// Walker utilities for AST traversal.
/// Provides a single-pass collector that builds flat lists of all expressions
/// and statements, plus helpers for rules that need custom traversal.
///
/// NOTE: This is one of 5 modules with expression tree traversal that must
/// stay in sync when glance adds new expression variants. The others are:
/// analysis.gleam, rules/deep_nesting.gleam, rules/missing_labels.gleam,
/// and unused_exports.gleam.
import glance.{type Expression, type Module, type Statement}
import gleam/list
import gleam/option.{None, Some}
import glinter/rule.{type ModuleData, ModuleData}

/// Wrap a module without collecting expressions or statements.
/// Use when no active rules need expression/statement lists.
pub fn module_only(module: Module) -> ModuleData {
  ModuleData(module: module, expressions: [], statements: [])
}

/// Walk the AST once, collecting all expressions and statements into flat lists.
pub fn collect(module: Module) -> ModuleData {
  let #(expressions, statements) =
    module.functions
    |> list.fold(#([], []), fn(acc, def) {
      collect_from_statements(def.definition.body, acc)
    })
  ModuleData(
    module: module,
    expressions: list.reverse(expressions),
    statements: list.reverse(statements),
  )
}

fn collect_from_statements(
  stmts: List(Statement),
  acc: #(List(Expression), List(Statement)),
) -> #(List(Expression), List(Statement)) {
  list.fold(stmts, acc, fn(acc, stmt) {
    let #(exprs, stmts) = acc
    let acc = #(exprs, [stmt, ..stmts])
    let expr = case stmt {
      glance.Expression(expr) -> expr
      glance.Assignment(value: expr, ..) -> expr
      glance.Use(function: expr, ..) -> expr
      glance.Assert(expression: expr, ..) -> expr
    }
    collect_from_expression(expr, acc)
  })
}

fn collect_from_expression(
  expr: Expression,
  acc: #(List(Expression), List(Statement)),
) -> #(List(Expression), List(Statement)) {
  let #(exprs, stmts) = acc
  let acc = #([expr, ..exprs], stmts)

  case expr {
    glance.Block(_, block_stmts) -> collect_from_statements(block_stmts, acc)

    glance.Fn(_, _, _, body) -> collect_from_statements(body, acc)

    glance.Case(_, subjects, clauses) -> {
      let acc =
        list.fold(subjects, acc, fn(acc, s) { collect_from_expression(s, acc) })
      list.fold(clauses, acc, fn(acc, clause) {
        collect_from_expression(clause.body, acc)
      })
    }

    glance.Call(_, function, arguments) -> {
      let acc = collect_from_expression(function, acc)
      list.fold(arguments, acc, fn(acc, field) {
        case field {
          glance.LabelledField(_, _, item) -> collect_from_expression(item, acc)
          glance.UnlabelledField(item) -> collect_from_expression(item, acc)
          glance.ShorthandField(_, _) -> acc
        }
      })
    }

    glance.Tuple(_, elements) ->
      list.fold(elements, acc, fn(acc, e) { collect_from_expression(e, acc) })

    glance.List(_, elements, rest) -> {
      let acc =
        list.fold(elements, acc, fn(acc, e) { collect_from_expression(e, acc) })
      case rest {
        Some(r) -> collect_from_expression(r, acc)
        None -> acc
      }
    }

    glance.BinaryOperator(_, _, left, right) -> {
      let acc = collect_from_expression(left, acc)
      collect_from_expression(right, acc)
    }

    glance.Echo(_, Some(inner), _) -> collect_from_expression(inner, acc)
    glance.Panic(_, Some(inner)) -> collect_from_expression(inner, acc)
    glance.Todo(_, Some(inner)) -> collect_from_expression(inner, acc)
    glance.FieldAccess(_, container, _) ->
      collect_from_expression(container, acc)
    glance.TupleIndex(_, tuple, _) -> collect_from_expression(tuple, acc)
    glance.NegateInt(_, inner) -> collect_from_expression(inner, acc)
    glance.NegateBool(_, inner) -> collect_from_expression(inner, acc)

    glance.RecordUpdate(_, _, _, _, fields) ->
      list.fold(fields, acc, fn(acc, field) {
        case field.item {
          Some(e) -> collect_from_expression(e, acc)
          None -> acc
        }
      })

    glance.FnCapture(_, _, function, args_before, args_after) -> {
      let acc = collect_from_expression(function, acc)
      let collect_field = fn(acc, field) {
        case field {
          glance.LabelledField(_, _, item) -> collect_from_expression(item, acc)
          glance.UnlabelledField(item) -> collect_from_expression(item, acc)
          glance.ShorthandField(_, _) -> acc
        }
      }
      let acc = list.fold(args_before, acc, collect_field)
      list.fold(args_after, acc, collect_field)
    }

    glance.BitString(_, segments) ->
      list.fold(segments, acc, fn(acc, seg) {
        collect_from_expression(seg.0, acc)
      })

    // Leaf nodes
    glance.Int(_, _)
    | glance.Float(_, _)
    | glance.String(_, _)
    | glance.Variable(_, _)
    | glance.Panic(_, None)
    | glance.Todo(_, None)
    | glance.Echo(_, None, _) -> acc
  }
}
