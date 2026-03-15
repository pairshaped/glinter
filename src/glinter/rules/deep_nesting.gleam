import glance.{type Expression, type Statement}
import gleam/int
import gleam/list
import gleam/option.{None, Some}
import glinter/rule.{type Rule, LintResult, Rule, Warning}

const threshold = 5

pub fn rule() -> Rule {
  Rule(name: "deep_nesting", default_severity: Warning, check: check)
}

fn check(data: rule.ModuleData, _source: String) -> List(rule.LintResult) {
  data.module.functions
  |> list.flat_map(fn(def) { check_stmts_depth(def.definition.body, 1) })
}

fn check_stmts_depth(
  stmts: List(Statement),
  depth: Int,
) -> List(rule.LintResult) {
  stmts
  |> list.flat_map(fn(stmt) { check_stmt_depth(stmt, depth) })
}

fn check_stmt_depth(stmt: Statement, depth: Int) -> List(rule.LintResult) {
  case stmt {
    glance.Expression(expr) -> check_expr_depth(expr, depth)
    glance.Assignment(value: expr, ..) -> check_expr_depth(expr, depth)
    glance.Use(function: expr, ..) -> check_expr_depth(expr, depth)
    glance.Assert(expression: expr, ..) -> check_expr_depth(expr, depth)
  }
}

fn check_expr_depth(expr: Expression, depth: Int) -> List(rule.LintResult) {
  case expr {
    glance.Block(location, stmts) -> {
      let new_depth = depth + 1
      case new_depth > threshold {
        True -> [
          LintResult(
            rule: "deep_nesting",
            severity: Warning,
            file: "",
            location: location,
            message: "Nesting is "
              <> int.to_string(new_depth)
              <> " levels deep — consider extracting a function or using early returns",
          ),
        ]
        False -> check_stmts_depth(stmts, new_depth)
      }
    }

    glance.Case(location, subjects, clauses) -> {
      let new_depth = depth + 1
      case new_depth > threshold {
        True -> [
          LintResult(
            rule: "deep_nesting",
            severity: Warning,
            file: "",
            location: location,
            message: "Nesting is "
              <> int.to_string(new_depth)
              <> " levels deep — consider extracting a function or using early returns",
          ),
        ]
        False -> {
          let subject_results =
            subjects
            |> list.flat_map(fn(s) { check_expr_depth(s, new_depth) })
          let clause_results =
            clauses
            |> list.flat_map(fn(clause) {
              check_expr_depth(clause.body, new_depth)
            })
          list.append(subject_results, clause_results)
        }
      }
    }

    glance.Fn(location, _, _, body) -> {
      let new_depth = depth + 1
      case new_depth > threshold {
        True -> [
          LintResult(
            rule: "deep_nesting",
            severity: Warning,
            file: "",
            location: location,
            message: "Nesting is "
              <> int.to_string(new_depth)
              <> " levels deep — consider extracting a function or using early returns",
          ),
        ]
        False -> check_stmts_depth(body, new_depth)
      }
    }

    // Recurse into non-nesting expressions
    glance.Call(_, function, arguments) -> {
      let fn_results = check_expr_depth(function, depth)
      let arg_results =
        arguments
        |> list.flat_map(fn(field) {
          case field {
            glance.LabelledField(_, _, item) -> check_expr_depth(item, depth)
            glance.UnlabelledField(item) -> check_expr_depth(item, depth)
            glance.ShorthandField(_, _) -> []
          }
        })
      list.append(fn_results, arg_results)
    }

    glance.BinaryOperator(_, _, left, right) ->
      list.append(check_expr_depth(left, depth), check_expr_depth(right, depth))

    glance.Tuple(_, elements) ->
      elements |> list.flat_map(fn(e) { check_expr_depth(e, depth) })

    glance.List(_, elements, rest) -> {
      let el_results =
        elements |> list.flat_map(fn(e) { check_expr_depth(e, depth) })
      let rest_results = case rest {
        Some(r) -> check_expr_depth(r, depth)
        None -> []
      }
      list.append(el_results, rest_results)
    }

    glance.Echo(_, Some(inner), _) -> check_expr_depth(inner, depth)
    glance.Panic(_, Some(inner)) -> check_expr_depth(inner, depth)
    glance.Todo(_, Some(inner)) -> check_expr_depth(inner, depth)
    glance.FieldAccess(_, container, _) -> check_expr_depth(container, depth)
    glance.TupleIndex(_, tuple, _) -> check_expr_depth(tuple, depth)
    glance.NegateInt(_, inner) -> check_expr_depth(inner, depth)
    glance.NegateBool(_, inner) -> check_expr_depth(inner, depth)

    glance.RecordUpdate(_, _, _, _, fields) ->
      fields
      |> list.flat_map(fn(field) {
        case field.item {
          Some(e) -> check_expr_depth(e, depth)
          None -> []
        }
      })

    glance.FnCapture(_, _, function, args_before, args_after) -> {
      let walk_field = fn(field) {
        case field {
          glance.LabelledField(_, _, item) -> check_expr_depth(item, depth)
          glance.UnlabelledField(item) -> check_expr_depth(item, depth)
          glance.ShorthandField(_, _) -> []
        }
      }
      list.append(
        check_expr_depth(function, depth),
        list.append(
          list.flat_map(args_before, walk_field),
          list.flat_map(args_after, walk_field),
        ),
      )
    }

    glance.BitString(_, segments) ->
      segments
      |> list.flat_map(fn(seg) { check_expr_depth(seg.0, depth) })

    // Leaf nodes
    glance.Int(_, _)
    | glance.Float(_, _)
    | glance.String(_, _)
    | glance.Variable(_, _)
    | glance.Panic(_, None)
    | glance.Todo(_, None)
    | glance.Echo(_, None, _) -> []
  }
}
