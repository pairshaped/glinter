/// NOTE: Expression tree traversal here must stay in sync with walker.gleam,
/// analysis.gleam, rules/deep_nesting.gleam, and unused_exports.gleam
/// when glance adds new expression variants.
import glance.{type Expression, type Statement}
import gleam/dict.{type Dict}
import gleam/int
import gleam/list
import gleam/option.{None, Some}
import glinter/rule.{type V2Rule, RuleResult, V2Rule, Warning}

pub fn rule() -> V2Rule {
  V2Rule(
    name: "missing_labels",
    default_severity: Warning,
    needs_collect: False,
    check: check,
  )
}

fn check(data: rule.ModuleData, _source: String) -> List(rule.RuleResult) {
  // Build dict of function name -> parameters
  let fn_params =
    data.module.functions
    |> list.fold(dict.new(), fn(acc, def) {
      dict.insert(acc, def.definition.name, def.definition.parameters)
    })

  // Walk all function bodies looking for calls
  data.module.functions
  |> list.flat_map(fn(def) { walk_stmts(def.definition.body, fn_params) })
}

fn walk_stmts(
  stmts: List(Statement),
  fn_params: Dict(String, List(glance.FunctionParameter)),
) -> List(rule.RuleResult) {
  stmts
  |> list.flat_map(fn(stmt) { walk_stmt(stmt, fn_params) })
}

fn walk_stmt(
  stmt: Statement,
  fn_params: Dict(String, List(glance.FunctionParameter)),
) -> List(rule.RuleResult) {
  case stmt {
    glance.Expression(expr) -> walk_expr(expr, fn_params)
    glance.Assignment(value: expr, ..) -> walk_expr(expr, fn_params)
    glance.Use(function: expr, ..) -> walk_expr(expr, fn_params)
    glance.Assert(expression: expr, ..) -> walk_expr(expr, fn_params)
  }
}

fn walk_expr(
  expr: Expression,
  fn_params: Dict(String, List(glance.FunctionParameter)),
) -> List(rule.RuleResult) {
  let call_results = case expr {
    glance.Call(location, glance.Variable(_, name), arguments) ->
      case dict.get(fn_params, name) {
        Ok(params) -> check_call(location, name, arguments, params)
        Error(_) -> []
      }
    _ -> []
  }

  let child_results = walk_children(expr, fn_params)
  list.append(call_results, child_results)
}

fn check_call(
  location: glance.Span,
  name: String,
  arguments: List(glance.Field(Expression)),
  params: List(glance.FunctionParameter),
) -> List(rule.RuleResult) {
  case list.length(arguments) == list.length(params) {
    False -> []
    True ->
      list.zip(arguments, params)
      |> list.index_map(fn(pair, idx) {
        let #(arg, param) = pair
        case param.label, arg {
          Some(label), glance.UnlabelledField(_) ->
            Ok(RuleResult(
              rule: "missing_labels",
              location: location,
              message: "Call to '"
                <> name
                <> "' is missing label '"
                <> label
                <> "' for argument "
                <> int.to_string(idx + 1),
            ))
          _, _ -> Error(Nil)
        }
      })
      |> list.filter_map(fn(x) { x })
  }
}

fn walk_children(
  expr: Expression,
  fn_params: Dict(String, List(glance.FunctionParameter)),
) -> List(rule.RuleResult) {
  case expr {
    glance.Block(_, stmts) -> walk_stmts(stmts, fn_params)

    glance.Case(_, subjects, clauses) -> {
      let subject_results =
        subjects |> list.flat_map(fn(s) { walk_expr(s, fn_params) })
      let clause_results =
        clauses
        |> list.flat_map(fn(clause) { walk_expr(clause.body, fn_params) })
      list.append(subject_results, clause_results)
    }

    glance.Call(_, function, arguments) -> {
      let fn_results = walk_expr(function, fn_params)
      let arg_results =
        arguments
        |> list.flat_map(fn(field) {
          case field {
            glance.LabelledField(_, _, item) -> walk_expr(item, fn_params)
            glance.UnlabelledField(item) -> walk_expr(item, fn_params)
            glance.ShorthandField(_, _) -> []
          }
        })
      list.append(fn_results, arg_results)
    }

    glance.Fn(_, _, _, body) -> walk_stmts(body, fn_params)

    glance.Tuple(_, elements) ->
      elements |> list.flat_map(fn(e) { walk_expr(e, fn_params) })

    glance.List(_, elements, rest) -> {
      let el_results =
        elements |> list.flat_map(fn(e) { walk_expr(e, fn_params) })
      let rest_results = case rest {
        Some(r) -> walk_expr(r, fn_params)
        None -> []
      }
      list.append(el_results, rest_results)
    }

    glance.BinaryOperator(_, _, left, right) ->
      list.append(walk_expr(left, fn_params), walk_expr(right, fn_params))

    glance.FieldAccess(_, container, _) -> walk_expr(container, fn_params)
    glance.TupleIndex(_, tuple, _) -> walk_expr(tuple, fn_params)
    glance.NegateInt(_, inner) -> walk_expr(inner, fn_params)
    glance.NegateBool(_, inner) -> walk_expr(inner, fn_params)
    glance.Echo(_, Some(inner), _) -> walk_expr(inner, fn_params)
    glance.Panic(_, Some(inner)) -> walk_expr(inner, fn_params)
    glance.Todo(_, Some(inner)) -> walk_expr(inner, fn_params)

    glance.RecordUpdate(_, _, _, _, fields) ->
      fields
      |> list.flat_map(fn(field) {
        case field.item {
          Some(e) -> walk_expr(e, fn_params)
          None -> []
        }
      })

    glance.FnCapture(_, _, function, args_before, args_after) -> {
      let walk_field = fn(field) {
        case field {
          glance.LabelledField(_, _, item) -> walk_expr(item, fn_params)
          glance.UnlabelledField(item) -> walk_expr(item, fn_params)
          glance.ShorthandField(_, _) -> []
        }
      }
      list.append(
        walk_expr(function, fn_params),
        list.append(
          list.flat_map(args_before, walk_field),
          list.flat_map(args_after, walk_field),
        ),
      )
    }

    glance.BitString(_, segments) ->
      segments
      |> list.flat_map(fn(seg) { walk_expr(seg.0, fn_params) })

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
