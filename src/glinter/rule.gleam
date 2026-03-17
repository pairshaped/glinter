import glance
import gleam/list
import gleam/option.{type Option, None, Some}

// --- Public types ---

pub type Severity {
  Error
  Warning
  Off
}

/// Full lint result with file path and severity, produced by the orchestrator.
pub type LintResult {
  LintResult(
    rule: String,
    severity: Severity,
    file: String,
    location: glance.Span,
    message: String,
    details: String,
  )
}

/// An error produced by a rule visitor. Opaque -- use `error()` to create.
pub opaque type RuleError {
  RuleError(message: String, details: String, location: glance.Span)
}

/// A fully-built rule. Opaque -- context types are erased via closures.
/// The orchestrator holds `List(Rule)` without knowing context types.
pub opaque type Rule {
  ModuleRule(
    name: String,
    default_severity: Severity,
    run: fn(glance.Module, String) -> List(RuleError),
  )
  ProjectRule(
    name: String,
    default_severity: Severity,
    run: fn(List(#(glance.Module, String))) -> List(RuleError),
  )
}

/// Builder type for module rules. Generic over the context type.
pub opaque type ModuleRuleSchema(context) {
  ModuleRuleSchema(
    name: String,
    default_severity: Severity,
    initial: fn() -> context,
    expression_enter_visitor: Option(
      fn(glance.Expression, glance.Span, context) -> #(List(RuleError), context),
    ),
    expression_exit_visitor: Option(
      fn(glance.Expression, glance.Span, context) -> #(List(RuleError), context),
    ),
    function_visitor: Option(
      fn(glance.Function, glance.Span, context) -> #(List(RuleError), context),
    ),
    import_visitor: Option(
      fn(glance.Definition(glance.Import), context) ->
        #(List(RuleError), context),
    ),
    statement_visitor: Option(
      fn(glance.Statement, context) -> #(List(RuleError), context),
    ),
    final_evaluation: Option(fn(context) -> List(RuleError)),
  )
}

/// Builder type for project rules. Generic over project and module context types.
pub opaque type ProjectRuleSchema(project_context, module_context) {
  ProjectRuleSchema(
    name: String,
    default_severity: Severity,
    initial: fn() -> project_context,
    module_visitor_builder: Option(
      fn(ModuleRuleSchema(module_context)) -> ModuleRuleSchema(module_context),
    ),
    from_project_to_module: Option(fn(project_context) -> module_context),
    from_module_to_project: Option(
      fn(module_context, project_context) -> project_context,
    ),
    // Stored here but called by the runner (Task 3), not this module.
    // The runner uses it to merge project contexts from parallel file processing.
    fold_project_contexts: Option(
      fn(project_context, project_context) -> project_context,
    ),
    final_project_evaluation: Option(fn(project_context) -> List(RuleError)),
  )
}

// --- Error constructor ---

/// Create an error with a message, details, and source location.
pub fn error(
  message message: String,
  details details: String,
  location location: glance.Span,
) -> RuleError {
  RuleError(message: message, details: details, location: location)
}

// --- Error accessors (for orchestrator/reporter) ---

pub fn error_message(err: RuleError) -> String {
  err.message
}

pub fn error_details(err: RuleError) -> String {
  err.details
}

pub fn error_location(err: RuleError) -> glance.Span {
  err.location
}

// --- Rule accessors ---

pub fn name(rule: Rule) -> String {
  case rule {
    ModuleRule(name: n, ..) -> n
    ProjectRule(name: n, ..) -> n
  }
}

pub fn default_severity(rule: Rule) -> Severity {
  case rule {
    ModuleRule(default_severity: severity, ..) -> severity
    ProjectRule(default_severity: severity, ..) -> severity
  }
}

pub fn is_project_rule(rule: Rule) -> Bool {
  case rule {
    ModuleRule(..) -> False
    ProjectRule(..) -> True
  }
}

// --- Module rule builder functions ---

/// Create a new module rule schema with no context.
pub fn new(name name: String) -> ModuleRuleSchema(Nil) {
  ModuleRuleSchema(
    name: name,
    default_severity: Warning,
    initial: fn() { Nil },
    expression_enter_visitor: None,
    expression_exit_visitor: None,
    function_visitor: None,
    import_visitor: None,
    statement_visitor: None,
    final_evaluation: None,
  )
}

/// Create a new module rule schema with an initial context value.
pub fn new_with_context(
  name name: String,
  initial initial: context,
) -> ModuleRuleSchema(context) {
  ModuleRuleSchema(
    name: name,
    default_severity: Warning,
    initial: fn() { initial },
    expression_enter_visitor: None,
    expression_exit_visitor: None,
    function_visitor: None,
    import_visitor: None,
    statement_visitor: None,
    final_evaluation: None,
  )
}

// --- Stateful visitors ---

pub fn with_expression_enter_visitor(
  schema schema: ModuleRuleSchema(context),
  visitor visitor: fn(glance.Expression, glance.Span, context) ->
    #(List(RuleError), context),
) -> ModuleRuleSchema(context) {
  ModuleRuleSchema(..schema, expression_enter_visitor: Some(visitor))
}

pub fn with_expression_exit_visitor(
  schema schema: ModuleRuleSchema(context),
  visitor visitor: fn(glance.Expression, glance.Span, context) ->
    #(List(RuleError), context),
) -> ModuleRuleSchema(context) {
  ModuleRuleSchema(..schema, expression_exit_visitor: Some(visitor))
}

pub fn with_function_visitor(
  schema schema: ModuleRuleSchema(context),
  visitor visitor: fn(glance.Function, glance.Span, context) ->
    #(List(RuleError), context),
) -> ModuleRuleSchema(context) {
  ModuleRuleSchema(..schema, function_visitor: Some(visitor))
}

pub fn with_import_visitor(
  schema schema: ModuleRuleSchema(context),
  visitor visitor: fn(glance.Definition(glance.Import), context) ->
    #(List(RuleError), context),
) -> ModuleRuleSchema(context) {
  ModuleRuleSchema(..schema, import_visitor: Some(visitor))
}

pub fn with_statement_visitor(
  schema schema: ModuleRuleSchema(context),
  visitor visitor: fn(glance.Statement, context) -> #(List(RuleError), context),
) -> ModuleRuleSchema(context) {
  ModuleRuleSchema(..schema, statement_visitor: Some(visitor))
}

// --- Simple visitors (no context) ---

pub fn with_simple_expression_visitor(
  schema schema: ModuleRuleSchema(context),
  visitor visitor: fn(glance.Expression, glance.Span) -> List(RuleError),
) -> ModuleRuleSchema(context) {
  ModuleRuleSchema(
    ..schema,
    expression_enter_visitor: Some(fn(expression, span, ctx) {
      #(visitor(expression, span), ctx)
    }),
  )
}

pub fn with_simple_function_visitor(
  schema schema: ModuleRuleSchema(context),
  visitor visitor: fn(glance.Function, glance.Span) -> List(RuleError),
) -> ModuleRuleSchema(context) {
  ModuleRuleSchema(
    ..schema,
    function_visitor: Some(fn(function, span, ctx) {
      #(visitor(function, span), ctx)
    }),
  )
}

pub fn with_simple_import_visitor(
  schema schema: ModuleRuleSchema(context),
  visitor visitor: fn(glance.Definition(glance.Import)) -> List(RuleError),
) -> ModuleRuleSchema(context) {
  ModuleRuleSchema(
    ..schema,
    import_visitor: Some(fn(definition, ctx) { #(visitor(definition), ctx) }),
  )
}

pub fn with_simple_statement_visitor(
  schema schema: ModuleRuleSchema(context),
  visitor visitor: fn(glance.Statement) -> List(RuleError),
) -> ModuleRuleSchema(context) {
  ModuleRuleSchema(
    ..schema,
    statement_visitor: Some(fn(statement, ctx) { #(visitor(statement), ctx) }),
  )
}

// --- Final evaluation ---

pub fn with_final_evaluation(
  schema schema: ModuleRuleSchema(context),
  evaluator evaluator: fn(context) -> List(RuleError),
) -> ModuleRuleSchema(context) {
  ModuleRuleSchema(..schema, final_evaluation: Some(evaluator))
}

// --- Severity builder ---

pub fn with_default_severity(
  schema schema: ModuleRuleSchema(context),
  severity severity: Severity,
) -> ModuleRuleSchema(context) {
  ModuleRuleSchema(..schema, default_severity: severity)
}

// --- Build module rule (type erasure) ---

/// Build a Rule from a ModuleRuleSchema, erasing the context type via closures.
pub fn to_module_rule(schema: ModuleRuleSchema(context)) -> Rule {
  ModuleRule(
    name: schema.name,
    default_severity: schema.default_severity,
    run: fn(module, source) { run_module_schema(schema, module, source) },
  )
}

/// Build a module Rule from a custom run function.
/// Use this when a rule needs access to the full module before visitor
/// traversal (e.g. pre-collecting function signatures).
pub fn module_rule_from_fn(
  name name: String,
  default_severity default_severity: Severity,
  run run: fn(glance.Module, String) -> List(RuleError),
) -> Rule {
  ModuleRule(name: name, default_severity: default_severity, run: run)
}

// --- Project rule builder functions ---

/// Create a new project rule schema with an initial project context.
pub fn new_project(
  name name: String,
  initial initial: project_context,
) -> ProjectRuleSchema(project_context, module_context) {
  ProjectRuleSchema(
    name: name,
    default_severity: Warning,
    initial: fn() { initial },
    module_visitor_builder: None,
    from_project_to_module: None,
    from_module_to_project: None,
    fold_project_contexts: None,
    final_project_evaluation: None,
  )
}

pub fn with_module_visitor(
  schema schema: ProjectRuleSchema(pc, mc),
  builder builder: fn(ModuleRuleSchema(mc)) -> ModuleRuleSchema(mc),
) -> ProjectRuleSchema(pc, mc) {
  ProjectRuleSchema(..schema, module_visitor_builder: Some(builder))
}

pub fn with_module_context(
  schema schema: ProjectRuleSchema(pc, mc),
  from_project_to_module from_project_to_module: fn(pc) -> mc,
  from_module_to_project from_module_to_project: fn(mc, pc) -> pc,
  fold_project_contexts fold_project_contexts: fn(pc, pc) -> pc,
) -> ProjectRuleSchema(pc, mc) {
  ProjectRuleSchema(
    ..schema,
    from_project_to_module: Some(from_project_to_module),
    from_module_to_project: Some(from_module_to_project),
    fold_project_contexts: Some(fold_project_contexts),
  )
}

pub fn with_final_project_evaluation(
  schema schema: ProjectRuleSchema(pc, mc),
  evaluator evaluator: fn(pc) -> List(RuleError),
) -> ProjectRuleSchema(pc, mc) {
  ProjectRuleSchema(..schema, final_project_evaluation: Some(evaluator))
}

pub fn with_project_default_severity(
  schema schema: ProjectRuleSchema(pc, mc),
  severity severity: Severity,
) -> ProjectRuleSchema(pc, mc) {
  ProjectRuleSchema(..schema, default_severity: severity)
}

/// Build a Rule from a ProjectRuleSchema, erasing context types via closures.
pub fn to_project_rule(schema: ProjectRuleSchema(pc, mc)) -> Rule {
  ProjectRule(
    name: schema.name,
    default_severity: schema.default_severity,
    run: fn(files) { run_project_schema(schema, files) },
  )
}

// --- Execution functions (called by orchestrator) ---

/// Run a module rule on a single parsed module. Returns errors.
pub fn run_on_module(
  rule rule: Rule,
  module module: glance.Module,
  source source: String,
) -> List(RuleError) {
  case rule {
    ModuleRule(run: run, ..) -> run(module, source)
    ProjectRule(..) -> []
  }
}

/// Run a project rule on all files. Returns errors.
pub fn run_on_project(
  rule rule: Rule,
  files files: List(#(glance.Module, String)),
) -> List(RuleError) {
  case rule {
    ProjectRule(run: run, ..) -> run(files)
    ModuleRule(..) -> []
  }
}

// --- Internal: run a module schema on a module ---

fn run_module_schema(
  schema: ModuleRuleSchema(context),
  module: glance.Module,
  source: String,
) -> List(RuleError) {
  let #(errors, _context) =
    run_module_schema_with_context(schema, module, source)
  errors
}

// --- Internal: run a project schema ---

fn run_project_schema(
  schema: ProjectRuleSchema(pc, mc),
  files: List(#(glance.Module, String)),
) -> List(RuleError) {
  let project_context = schema.initial()

  // Build the module rule schema if we have both a builder and context bridging
  case
    schema.module_visitor_builder,
    schema.from_project_to_module,
    schema.from_module_to_project
  {
    Some(builder), Some(to_module), Some(to_project) -> {
      // For each file, create module context from project, run module visitors,
      // then fold module context back into project context
      let #(module_errors, project_context) =
        list.fold(files, #([], project_context), fn(acc, file) {
          let #(errors_so_far, pc) = acc
          let #(module, source) = file
          let mc = to_module(pc)

          // Build a module schema with the module context
          let base_schema =
            ModuleRuleSchema(
              name: schema.name,
              default_severity: schema.default_severity,
              initial: fn() { mc },
              expression_enter_visitor: None,
              expression_exit_visitor: None,
              function_visitor: None,
              import_visitor: None,
              statement_visitor: None,
              final_evaluation: None,
            )
          let module_schema = builder(base_schema)

          // Run it and get the context back
          let #(errors, final_mc) =
            run_module_schema_with_context(module_schema, module, source)

          let new_pc = to_project(final_mc, pc)
          #(list.append(errors_so_far, errors), new_pc)
        })

      // Run final project evaluation
      let final_errors = case schema.final_project_evaluation {
        None -> []
        Some(evaluator) -> evaluator(project_context)
      }

      list.append(module_errors, final_errors)
    }
    _, _, _ -> {
      // No module visitor setup -- just run final project evaluation
      case schema.final_project_evaluation {
        None -> []
        Some(evaluator) -> evaluator(project_context)
      }
    }
  }
}

// --- Public: visit a module with a rule schema (recursive traversal) ---

/// Visit a module with a rule schema, returning errors and final context.
/// Drives all registered visitors through a depth-first AST traversal.
pub fn visit_module(
  module module: glance.Module,
  schema schema: ModuleRuleSchema(context),
  source source: String,
) -> #(List(RuleError), context) {
  run_module_schema_with_context(schema, module, source)
}

// --- Internal: run module schema and return both errors and final context ---

fn run_module_schema_with_context(
  schema: ModuleRuleSchema(context),
  module: glance.Module,
  _source: String,
) -> #(List(RuleError), context) {
  let context = schema.initial()

  // 1. Visit imports
  let #(errors, context) =
    list.fold(module.imports, #([], context), fn(acc, import_def) {
      let #(errors_so_far, ctx) = acc
      case schema.import_visitor {
        None -> acc
        Some(visitor) -> {
          let #(new_errors, new_ctx) = visitor(import_def, ctx)
          #(list.append(errors_so_far, new_errors), new_ctx)
        }
      }
    })

  // 2. Visit functions and their bodies
  let #(func_errors, context) =
    list.fold(module.functions, #([], context), fn(acc, func_def) {
      let #(errors_so_far, ctx) = acc
      let function = func_def.definition

      // 2a. Call function visitor
      let #(fn_errors, ctx) = case schema.function_visitor {
        None -> #([], ctx)
        Some(visitor) -> visitor(function, function.location, ctx)
      }

      // 2b. Walk the function body (list of statements)
      let #(body_errors, ctx) =
        visit_statements(schema, function.body, #([], ctx))

      #(list.flatten([errors_so_far, fn_errors, body_errors]), ctx)
    })

  // 3. Final evaluation
  let #(final_errors, context) = case schema.final_evaluation {
    None -> #([], context)
    Some(evaluator) -> #(evaluator(context), context)
  }

  #(list.flatten([errors, func_errors, final_errors]), context)
}

// --- Internal: visit a list of statements ---

fn visit_statements(
  schema: ModuleRuleSchema(context),
  statements: List(glance.Statement),
  acc: #(List(RuleError), context),
) -> #(List(RuleError), context) {
  list.fold(statements, acc, fn(acc, statement) {
    let #(errors_so_far, ctx) = acc

    // Call statement visitor
    let #(stmt_errors, ctx) = case schema.statement_visitor {
      None -> #([], ctx)
      Some(visitor) -> visitor(statement, ctx)
    }

    // Extract expression(s) from the statement and recurse
    let expressions = statement_expressions(statement)
    let #(expr_errors, ctx) =
      list.fold(expressions, #([], ctx), fn(acc2, expr_span) {
        let #(expr_errors_so_far, ctx2) = acc2
        let #(expression, span) = expr_span
        let #(new_errors, new_ctx) =
          visit_expression(schema, expression, span, ctx2)
        #(list.append(expr_errors_so_far, new_errors), new_ctx)
      })

    #(list.flatten([errors_so_far, stmt_errors, expr_errors]), ctx)
  })
}

// --- Internal: recursively visit an expression (depth-first) ---

fn visit_expression(
  schema: ModuleRuleSchema(context),
  expression: glance.Expression,
  span: glance.Span,
  context: context,
) -> #(List(RuleError), context) {
  // 1. Enter visitor (top-down)
  let #(enter_errors, context) = case schema.expression_enter_visitor {
    None -> #([], context)
    Some(visitor) -> visitor(expression, span, context)
  }

  // 2. Recurse into children
  let #(child_errors, context) =
    visit_expression_children(schema, expression, context)

  // 3. Exit visitor (bottom-up)
  let #(exit_errors, context) = case schema.expression_exit_visitor {
    None -> #([], context)
    Some(visitor) -> visitor(expression, span, context)
  }

  #(list.flatten([enter_errors, child_errors, exit_errors]), context)
}

fn visit_expression_children(
  schema: ModuleRuleSchema(context),
  expression: glance.Expression,
  context: context,
) -> #(List(RuleError), context) {
  case expression {
    // Nodes with statement bodies
    glance.Block(_, statements) ->
      visit_statements(schema, statements, #([], context))

    glance.Fn(_, _, _, body) -> visit_statements(schema, body, #([], context))

    // Case: recurse into subjects, then clause guards and bodies
    glance.Case(_, subjects, clauses) -> {
      let #(subject_errors, context) =
        visit_expression_list(schema, subjects, context)
      let #(clause_errors, context) =
        list.fold(clauses, #([], context), fn(acc, clause) {
          let #(errors_so_far, ctx) = acc
          // Visit guard expression if present
          let #(guard_errors, ctx) = case clause.guard {
            Some(guard_expr) -> {
              let guard_span = expression_span(guard_expr)
              visit_expression(schema, guard_expr, guard_span, ctx)
            }
            None -> #([], ctx)
          }
          let body_span = expression_span(clause.body)
          let #(body_errors, new_ctx) =
            visit_expression(schema, clause.body, body_span, ctx)
          #(list.flatten([errors_so_far, guard_errors, body_errors]), new_ctx)
        })
      #(list.append(subject_errors, clause_errors), context)
    }

    // Call: recurse into function, then arguments
    glance.Call(_, function, arguments) -> {
      let fn_span = expression_span(function)
      let #(fn_errors, context) =
        visit_expression(schema, function, fn_span, context)
      let #(arg_errors, context) = visit_fields(schema, arguments, context)
      #(list.append(fn_errors, arg_errors), context)
    }

    // Tuple: recurse into elements
    glance.Tuple(_, elements) ->
      visit_expression_list(schema, elements, context)

    // List: recurse into elements, then optional rest
    glance.List(_, elements, rest) -> {
      let #(elem_errors, context) =
        visit_expression_list(schema, elements, context)
      let #(rest_errors, context) = case rest {
        Some(rest_expr) -> {
          let rest_span = expression_span(rest_expr)
          visit_expression(schema, rest_expr, rest_span, context)
        }
        None -> #([], context)
      }
      #(list.append(elem_errors, rest_errors), context)
    }

    // BinaryOperator: recurse into left, right
    glance.BinaryOperator(_, _, left, right) -> {
      let left_span = expression_span(left)
      let #(left_errors, context) =
        visit_expression(schema, left, left_span, context)
      let right_span = expression_span(right)
      let #(right_errors, context) =
        visit_expression(schema, right, right_span, context)
      #(list.append(left_errors, right_errors), context)
    }

    // Echo: recurse into expression and message (both optional)
    glance.Echo(_, expression_opt, message_opt) -> {
      let #(expr_errors, context) = case expression_opt {
        Some(inner) -> {
          let inner_span = expression_span(inner)
          visit_expression(schema, inner, inner_span, context)
        }
        None -> #([], context)
      }
      let #(msg_errors, context) = case message_opt {
        Some(msg) -> {
          let msg_span = expression_span(msg)
          visit_expression(schema, msg, msg_span, context)
        }
        None -> #([], context)
      }
      #(list.append(expr_errors, msg_errors), context)
    }
    glance.Panic(_, Some(inner)) -> {
      let inner_span = expression_span(inner)
      visit_expression(schema, inner, inner_span, context)
    }
    glance.Todo(_, Some(inner)) -> {
      let inner_span = expression_span(inner)
      visit_expression(schema, inner, inner_span, context)
    }
    glance.FieldAccess(_, container, _) -> {
      let container_span = expression_span(container)
      visit_expression(schema, container, container_span, context)
    }
    glance.TupleIndex(_, tuple, _) -> {
      let tuple_span = expression_span(tuple)
      visit_expression(schema, tuple, tuple_span, context)
    }
    glance.NegateInt(_, inner) -> {
      let inner_span = expression_span(inner)
      visit_expression(schema, inner, inner_span, context)
    }
    glance.NegateBool(_, inner) -> {
      let inner_span = expression_span(inner)
      visit_expression(schema, inner, inner_span, context)
    }

    // RecordUpdate: recurse into record expression and field values
    glance.RecordUpdate(_, _, _, record, fields) -> {
      let record_span = expression_span(record)
      let #(record_errors, context) =
        visit_expression(schema, record, record_span, context)
      let #(field_errors, context) =
        list.fold(fields, #([], context), fn(acc, field) {
          let #(errors_so_far, ctx) = acc
          case field.item {
            Some(expr) -> {
              let expr_span = expression_span(expr)
              let #(new_errors, new_ctx) =
                visit_expression(schema, expr, expr_span, ctx)
              #(list.append(errors_so_far, new_errors), new_ctx)
            }
            None -> acc
          }
        })
      #(list.append(record_errors, field_errors), context)
    }

    // FnCapture: recurse into function, args_before, args_after
    glance.FnCapture(_, _, function, args_before, args_after) -> {
      let fn_span = expression_span(function)
      let #(fn_errors, context) =
        visit_expression(schema, function, fn_span, context)
      let #(before_errors, context) = visit_fields(schema, args_before, context)
      let #(after_errors, context) = visit_fields(schema, args_after, context)
      #(list.flatten([fn_errors, before_errors, after_errors]), context)
    }

    // BitString: recurse into segment values
    glance.BitString(_, segments) ->
      list.fold(segments, #([], context), fn(acc, segment) {
        let #(errors_so_far, ctx) = acc
        let expr = segment.0
        let seg_span = expression_span(expr)
        let #(new_errors, new_ctx) =
          visit_expression(schema, expr, seg_span, ctx)
        #(list.append(errors_so_far, new_errors), new_ctx)
      })

    // Leaf nodes -- no children to recurse into
    glance.Int(_, _)
    | glance.Float(_, _)
    | glance.String(_, _)
    | glance.Variable(_, _)
    | glance.Panic(_, None)
    | glance.Todo(_, None) -> #([], context)
  }
}

// --- Internal: visit a list of expressions ---

fn visit_expression_list(
  schema: ModuleRuleSchema(context),
  expressions: List(glance.Expression),
  context: context,
) -> #(List(RuleError), context) {
  list.fold(expressions, #([], context), fn(acc, expr) {
    let #(errors_so_far, ctx) = acc
    let expr_span = expression_span(expr)
    let #(new_errors, new_ctx) = visit_expression(schema, expr, expr_span, ctx)
    #(list.append(errors_so_far, new_errors), new_ctx)
  })
}

// --- Internal: visit Field arguments (Call, FnCapture) ---

fn visit_fields(
  schema: ModuleRuleSchema(context),
  fields: List(glance.Field(glance.Expression)),
  context: context,
) -> #(List(RuleError), context) {
  list.fold(fields, #([], context), fn(acc, field) {
    let #(errors_so_far, ctx) = acc
    case field {
      glance.LabelledField(_, _, item) | glance.UnlabelledField(item) -> {
        let item_span = expression_span(item)
        let #(new_errors, new_ctx) =
          visit_expression(schema, item, item_span, ctx)
        #(list.append(errors_so_far, new_errors), new_ctx)
      }
      glance.ShorthandField(_, _) -> acc
    }
  })
}

// --- Internal: extract expressions from a statement ---

fn statement_expressions(
  statement: glance.Statement,
) -> List(#(glance.Expression, glance.Span)) {
  case statement {
    glance.Use(location: location, function: expression, ..) -> [
      #(expression, location),
    ]
    glance.Assignment(location: location, value: expression, ..) -> [
      #(expression, location),
    ]
    glance.Expression(expression) -> {
      let span = expression_span(expression)
      [#(expression, span)]
    }
    glance.Assert(location: location, expression: expression, ..) -> [
      #(expression, location),
    ]
  }
}

fn expression_span(expression: glance.Expression) -> glance.Span {
  case expression {
    glance.Int(location: location, ..)
    | glance.Float(location: location, ..)
    | glance.String(location: location, ..)
    | glance.Variable(location: location, ..)
    | glance.NegateInt(location: location, ..)
    | glance.NegateBool(location: location, ..)
    | glance.Block(location: location, ..)
    | glance.Panic(location: location, ..)
    | glance.Todo(location: location, ..)
    | glance.Tuple(location: location, ..)
    | glance.List(location: location, ..)
    | glance.Fn(location: location, ..)
    | glance.RecordUpdate(location: location, ..)
    | glance.FieldAccess(location: location, ..)
    | glance.Call(location: location, ..)
    | glance.TupleIndex(location: location, ..)
    | glance.FnCapture(location: location, ..)
    | glance.BitString(location: location, ..)
    | glance.Case(location: location, ..)
    | glance.BinaryOperator(location: location, ..)
    | glance.Echo(location: location, ..) -> location
  }
}

// --- V2 compatibility types (will be removed when rules are ported) ---

/// @deprecated Use RuleError with the new visitor API instead
pub type RuleResult {
  RuleResult(rule: String, location: glance.Span, message: String)
}

/// @deprecated Use the new visitor API instead
pub type ModuleData {
  ModuleData(
    module: glance.Module,
    expressions: List(glance.Expression),
    statements: List(glance.Statement),
  )
}

/// @deprecated Use the new builder API (new/to_module_rule) instead
pub type V2Rule {
  V2Rule(
    name: String,
    default_severity: Severity,
    needs_collect: Bool,
    check: fn(ModuleData, String) -> List(RuleResult),
  )
}

/// Convert a V2Rule to the new Rule type for runner compatibility.
/// Accepts a module_data_builder to avoid an import cycle with walker.
pub fn from_v2_rule(
  v2 v2: V2Rule,
  module_data_builder module_data_builder: fn(glance.Module, Bool) -> ModuleData,
) -> Rule {
  ModuleRule(
    name: v2.name,
    default_severity: v2.default_severity,
    run: fn(module, source) {
      let data = module_data_builder(module, v2.needs_collect)
      v2.check(data, source)
      |> list.map(fn(result) {
        RuleError(
          message: result.message,
          details: "",
          location: result.location,
        )
      })
    },
  )
}
