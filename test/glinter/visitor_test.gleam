import glance
import gleam/list
import gleam/string
import glinter/rule

// --- Test 1: Expression enter visitor visits all expressions recursively ---

pub fn expression_enter_visitor_visits_recursively_test() {
  // `1 + 2` should visit: BinaryOperator, Int(1), Int(2) = at least 3
  let #(errors, count) =
    rule.new_with_context(name: "count_exprs", initial: 0)
    |> rule.with_expression_enter_visitor(visitor: fn(_expr, _span, count) {
      #([], count + 1)
    })
    |> visit_source("pub fn main() { 1 + 2 }")

  let assert True = errors == []
  // BinaryOperator + Int + Int = 3
  let assert True = count >= 3
}

// --- Test 2: Expression visitor visits nested expressions ---

pub fn expression_visitor_visits_nested_calls_test() {
  // list.map([1, 2, 3], fn(x) { x + 1 })
  // Should reach the inner `x + 1` (BinaryOperator inside the fn body)
  let source =
    "import gleam/list\npub fn main() { list.map([1, 2, 3], fn(x) { x + 1 }) }"

  let #(_errors, found_inner_binop) =
    rule.new_with_context(name: "find_nested", initial: False)
    |> rule.with_expression_enter_visitor(visitor: fn(expression, _span, found) {
      case expression {
        glance.BinaryOperator(_, _, glance.Variable(_, "x"), _) -> #([], True)
        _ -> #([], found)
      }
    })
    |> visit_source(source)

  let assert True = found_inner_binop
}

// --- Test 3: Expression exit visitor fires bottom-up ---

pub fn expression_exit_visitor_fires_bottom_up_test() {
  // For `1 + 2`:
  // Enter order: BinaryOperator, Int(1), Int(2)
  // Exit order:  Int(1), Int(2), BinaryOperator
  let #(_errors, #(enter_order, exit_order)) =
    rule.new_with_context(name: "order_test", initial: #([], []))
    |> rule.with_expression_enter_visitor(visitor: fn(expression, _span, ctx) {
      let #(enters, exits) = ctx
      let label = expression_label(expression)
      #([], #(list.append(enters, [label]), exits))
    })
    |> rule.with_expression_exit_visitor(visitor: fn(expression, _span, ctx) {
      let #(enters, exits) = ctx
      let label = expression_label(expression)
      #([], #(enters, list.append(exits, [label])))
    })
    |> visit_source("pub fn main() { 1 + 2 }")

  // Enter: BinaryOperator first
  let assert True = list.first(enter_order) == Ok("BinaryOperator")
  // Exit: BinaryOperator last
  let assert True = list.last(exit_order) == Ok("BinaryOperator")

  // Enter: Int appears after BinaryOperator
  let assert True = list.length(enter_order) == 3
  let assert True = list.last(enter_order) != Ok("BinaryOperator")

  // Exit: Int appears before BinaryOperator
  let assert True = list.length(exit_order) == 3
  let assert True = list.first(exit_order) != Ok("BinaryOperator")
}

// --- Test 4: Function visitor receives each function ---

pub fn function_visitor_collects_all_functions_test() {
  let source = "pub fn add() { 1 }\npub fn sub() { 2 }"

  let #(_errors, names) =
    rule.new_with_context(name: "collect_fns", initial: [])
    |> rule.with_function_visitor(visitor: fn(definition, _span, names) {
      #([], list.append(names, [definition.definition.name]))
    })
    |> visit_source(source)

  let assert True = list.length(names) == 2
  let assert True = list.contains(names, "add")
  let assert True = list.contains(names, "sub")
}

// --- Test 5: Import visitor receives each import ---

pub fn import_visitor_receives_all_imports_test() {
  let source = "import gleam/list\nimport gleam/int\npub fn main() { 1 }"

  let #(_errors, count) =
    rule.new_with_context(name: "count_imports", initial: 0)
    |> rule.with_import_visitor(visitor: fn(_import_def, count) {
      #([], count + 1)
    })
    |> visit_source(source)

  let assert True = count == 2
}

// --- Test 6: Statement visitor receives statements ---

pub fn statement_visitor_receives_assignments_test() {
  let source = "pub fn main() { let a = 1\nlet b = 2\na + b }"

  let #(_errors, count) =
    rule.new_with_context(name: "count_stmts", initial: 0)
    |> rule.with_statement_visitor(visitor: fn(statement, count) {
      case statement {
        glance.Assignment(..) -> #([], count + 1)
        _ -> #([], count)
      }
    })
    |> visit_source(source)

  let assert True = count == 2
}

// --- Test 7: Visitor walks into Case clauses ---

pub fn visitor_walks_into_case_clauses_test() {
  let source = "pub fn main() { case True { True -> 42\nFalse -> 0 } }"

  // Count Int expressions inside case clauses
  let #(_errors, int_count) =
    rule.new_with_context(name: "case_walk", initial: 0)
    |> rule.with_expression_enter_visitor(visitor: fn(expression, _span, count) {
      case expression {
        glance.Int(..) -> #([], count + 1)
        _ -> #([], count)
      }
    })
    |> visit_source(source)

  // Should find Int(42) and Int(0)
  let assert True = int_count >= 2
}

// --- Test 8: Visitor walks into Block/Fn bodies ---

pub fn visitor_walks_into_anonymous_fn_test() {
  let source = "pub fn main() { fn() { 99 } }"

  let #(_errors, found_99) =
    rule.new_with_context(name: "anon_fn_walk", initial: False)
    |> rule.with_expression_enter_visitor(visitor: fn(expression, _span, found) {
      case expression {
        glance.Int(_, "99") -> #([], True)
        _ -> #([], found)
      }
    })
    |> visit_source(source)

  let assert True = found_99
}

// --- Test 9: Context threads correctly through enter/exit ---

pub fn context_threads_through_enter_exit_test() {
  // Track depth: increment on enter for Block/Fn/Case, decrement on exit
  let source = "pub fn main() { case True { True -> { 1 } _ -> 2 } }"

  let #(_errors, #(depth, max_depth)) =
    rule.new_with_context(name: "depth_test", initial: #(0, 0))
    |> rule.with_expression_enter_visitor(visitor: fn(expression, _span, ctx) {
      let #(depth, max_depth) = ctx
      case expression {
        glance.Block(..) | glance.Fn(..) | glance.Case(..) -> {
          let new_depth = depth + 1
          let new_max = case new_depth > max_depth {
            True -> new_depth
            False -> max_depth
          }
          #([], #(new_depth, new_max))
        }
        _ -> #([], ctx)
      }
    })
    |> rule.with_expression_exit_visitor(visitor: fn(expression, _span, ctx) {
      let #(depth, max_depth) = ctx
      case expression {
        glance.Block(..) | glance.Fn(..) | glance.Case(..) -> #(
          [],
          #(depth - 1, max_depth),
        )
        _ -> #([], ctx)
      }
    })
    |> visit_source(source)

  // Depth should return to 0 after traversal
  let assert True = depth == 0
  // Should have reached at least depth 1 (the case expression)
  let assert True = max_depth >= 1
}

// --- Test 10: Final evaluation receives accumulated context ---

pub fn final_evaluation_receives_context_test() {
  let source = "pub fn a() { 1 }\npub fn b() { 2 }\npub fn c() { 3 }"

  let #(errors, _context) =
    rule.new_with_context(name: "fn_count_check", initial: 0)
    |> rule.with_function_visitor(visitor: fn(_function, _span, count) {
      #([], count + 1)
    })
    |> rule.with_final_evaluation(evaluator: fn(count) {
      case count > 2 {
        True -> [
          rule.error(
            message: "Too many functions: " <> string.inspect(count),
            details: "",
            location: glance.Span(start: 0, end: 0),
          ),
        ]
        False -> []
      }
    })
    |> visit_source(source)

  let assert True = list.length(errors) == 1
  let assert [err] = errors
  let assert True =
    string.contains(rule.error_message(err), contain: "Too many functions")
}

// --- Helpers ---

/// Parse source and run visit_module, returning errors and final context.
fn visit_source(
  schema: rule.ModuleRuleSchema(context),
  source: String,
) -> #(List(rule.RuleError), context) {
  let assert Ok(module) = glance.module(source)
  rule.visit_module(module: module, schema: schema, source: source)
}

/// Label an expression variant for ordering tests.
fn expression_label(expression: glance.Expression) -> String {
  case expression {
    glance.Int(..) -> "Int"
    glance.Float(..) -> "Float"
    glance.String(..) -> "String"
    glance.Variable(..) -> "Variable"
    glance.BinaryOperator(..) -> "BinaryOperator"
    glance.Call(..) -> "Call"
    glance.Fn(..) -> "Fn"
    glance.Block(..) -> "Block"
    glance.Case(..) -> "Case"
    glance.Tuple(..) -> "Tuple"
    glance.List(..) -> "List"
    glance.Panic(..) -> "Panic"
    glance.Todo(..) -> "Todo"
    glance.Echo(..) -> "Echo"
    glance.NegateInt(..) -> "NegateInt"
    glance.NegateBool(..) -> "NegateBool"
    glance.FieldAccess(..) -> "FieldAccess"
    glance.TupleIndex(..) -> "TupleIndex"
    glance.RecordUpdate(..) -> "RecordUpdate"
    glance.FnCapture(..) -> "FnCapture"
    glance.BitString(..) -> "BitString"
  }
}
