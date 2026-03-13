import glance.{
  type Expression, type Module, type Statement,
}
import gleam/list
import gleam/option.{None, Some}
import glinter/rule.{type LintResult, type Rule, LintResult}

pub fn walk_module(
  module: Module,
  rules: List(Rule),
  _source: String,
  file: String,
) -> List(LintResult) {
  let module_results =
    rules
    |> list.flat_map(fn(r) {
      case r.check_module {
        Some(check) ->
          check(module)
          |> list.map(fn(result) {
            LintResult(..result, severity: r.default_severity)
          })
        None -> []
      }
    })

  let function_results =
    module.functions
    |> list.flat_map(fn(def) {
      let func = def.definition
      let fn_results = run_function_rules(func, rules)
      let body_results =
        func.body
        |> list.flat_map(fn(stmt) { walk_statement(stmt, rules) })
      list.append(fn_results, body_results)
    })

  list.append(module_results, function_results)
  |> list.map(fn(result) { LintResult(..result, file: file) })
}

fn run_function_rules(
  func: glance.Function,
  rules: List(Rule),
) -> List(LintResult) {
  rules
  |> list.flat_map(fn(r) {
    case r.check_function {
      Some(check) ->
        check(func)
        |> list.map(fn(result) {
          LintResult(..result, severity: r.default_severity)
        })
      None -> []
    }
  })
}

fn walk_statement(stmt: Statement, rules: List(Rule)) -> List(LintResult) {
  let statement_results =
    rules
    |> list.flat_map(fn(r) {
      case r.check_statement {
        Some(check) ->
          check(stmt)
          |> list.map(fn(result) {
            LintResult(..result, severity: r.default_severity)
          })
        None -> []
      }
    })

  let expression_results = case stmt {
    glance.Expression(expr) -> walk_expression(expr, rules)
    glance.Assignment(value: expr, ..) -> walk_expression(expr, rules)
    glance.Use(function: expr, ..) -> walk_expression(expr, rules)
    glance.Assert(expression: expr, ..) -> walk_expression(expr, rules)
  }

  list.append(statement_results, expression_results)
}

fn walk_expression(expr: Expression, rules: List(Rule)) -> List(LintResult) {
  let expr_results =
    rules
    |> list.flat_map(fn(r) {
      case r.check_expression {
        Some(check) ->
          check(expr)
          |> list.map(fn(result) {
            LintResult(..result, severity: r.default_severity)
          })
        None -> []
      }
    })

  let child_results = case expr {
    glance.Block(_, stmts) ->
      stmts |> list.flat_map(fn(s) { walk_statement(s, rules) })

    glance.Case(_, subjects, clauses) -> {
      let subject_results =
        subjects |> list.flat_map(fn(s) { walk_expression(s, rules) })
      let clause_results =
        clauses
        |> list.flat_map(fn(clause) { walk_expression(clause.body, rules) })
      list.append(subject_results, clause_results)
    }

    glance.Call(_, function, arguments) -> {
      let fn_results = walk_expression(function, rules)
      let arg_results =
        arguments
        |> list.flat_map(fn(field) {
          case field {
            glance.LabelledField(_, _, item) -> walk_expression(item, rules)
            glance.UnlabelledField(item) -> walk_expression(item, rules)
            glance.ShorthandField(_, _) -> []
          }
        })
      list.append(fn_results, arg_results)
    }

    glance.Fn(_, _, _, body) ->
      body |> list.flat_map(fn(s) { walk_statement(s, rules) })

    glance.Tuple(_, elements) ->
      elements |> list.flat_map(fn(e) { walk_expression(e, rules) })

    glance.List(_, elements, rest) -> {
      let el_results =
        elements |> list.flat_map(fn(e) { walk_expression(e, rules) })
      let rest_results = case rest {
        Some(r) -> walk_expression(r, rules)
        None -> []
      }
      list.append(el_results, rest_results)
    }

    glance.Echo(_, Some(inner), _) -> walk_expression(inner, rules)

    glance.Panic(_, Some(inner)) -> walk_expression(inner, rules)

    glance.Todo(_, Some(inner)) -> walk_expression(inner, rules)

    glance.RecordUpdate(_, _, _, _, fields) ->
      fields
      |> list.flat_map(fn(field) {
        case field.item {
          Some(expr) -> walk_expression(expr, rules)
          None -> []
        }
      })

    glance.FieldAccess(_, container, _) -> walk_expression(container, rules)

    glance.TupleIndex(_, tuple, _) -> walk_expression(tuple, rules)

    glance.NegateInt(_, inner) -> walk_expression(inner, rules)

    glance.NegateBool(_, inner) -> walk_expression(inner, rules)

    glance.BinaryOperator(_, _, left, right) -> {
      let l = walk_expression(left, rules)
      let r = walk_expression(right, rules)
      list.append(l, r)
    }

    glance.FnCapture(_, _, function, args_before, args_after) -> {
      let fn_results = walk_expression(function, rules)
      let walk_field = fn(field) {
        case field {
          glance.LabelledField(_, _, item) -> walk_expression(item, rules)
          glance.UnlabelledField(item) -> walk_expression(item, rules)
          glance.ShorthandField(_, _) -> []
        }
      }
      let before_results = args_before |> list.flat_map(walk_field)
      let after_results = args_after |> list.flat_map(walk_field)
      list.append(fn_results, list.append(before_results, after_results))
    }

    glance.BitString(_, segments) ->
      segments
      |> list.flat_map(fn(seg) { walk_expression(seg.0, rules) })

    // Leaf nodes
    glance.Int(_, _)
    | glance.Float(_, _)
    | glance.String(_, _)
    | glance.Variable(_, _)
    | glance.Panic(_, None)
    | glance.Todo(_, None)
    | glance.Echo(_, None, _)
    -> []
  }

  list.append(expr_results, child_results)
}
