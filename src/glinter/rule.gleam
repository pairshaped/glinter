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
    initial: fn() -> project_context,
    module_visitor_builder: Option(
      fn(ModuleRuleSchema(module_context)) -> ModuleRuleSchema(module_context),
    ),
    from_project_to_module: Option(fn(project_context) -> module_context),
    from_module_to_project: Option(
      fn(module_context, project_context) -> project_context,
    ),
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

// --- Build module rule (type erasure) ---

/// Build a Rule from a ModuleRuleSchema, erasing the context type via closures.
pub fn to_module_rule(schema: ModuleRuleSchema(context)) -> Rule {
  ModuleRule(
    name: schema.name,
    default_severity: Warning,
    run: fn(module, source) { run_module_schema(schema, module, source) },
  )
}

// --- Project rule builder functions ---

/// Create a new project rule schema with an initial project context.
pub fn new_project(
  name name: String,
  initial initial: project_context,
) -> ProjectRuleSchema(project_context, module_context) {
  ProjectRuleSchema(
    name: name,
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

/// Build a Rule from a ProjectRuleSchema, erasing context types via closures.
pub fn to_project_rule(schema: ProjectRuleSchema(pc, mc)) -> Rule {
  ProjectRule(name: schema.name, default_severity: Warning, run: fn(files) {
    run_project_schema(schema, files)
  })
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

// --- Internal: run module schema and return both errors and final context ---

fn run_module_schema_with_context(
  schema: ModuleRuleSchema(context),
  module: glance.Module,
  _source: String,
) -> #(List(RuleError), context) {
  let context = schema.initial()

  // Run import visitors
  let #(import_errors, context) = case schema.import_visitor {
    None -> #([], context)
    Some(visitor) ->
      list.fold(module.imports, #([], context), fn(acc, import_def) {
        let #(errors_so_far, ctx) = acc
        let #(new_errors, new_ctx) = visitor(import_def, ctx)
        #(list.append(errors_so_far, new_errors), new_ctx)
      })
  }

  // Run function visitors
  let #(function_errors, context) = case schema.function_visitor {
    None -> #([], context)
    Some(visitor) ->
      list.fold(module.functions, #([], context), fn(acc, func_def) {
        let #(errors_so_far, ctx) = acc
        let function = func_def.definition
        let #(new_errors, new_ctx) = visitor(function, function.location, ctx)
        #(list.append(errors_so_far, new_errors), new_ctx)
      })
  }

  // Run statement visitors
  let #(statement_errors, context) = case schema.statement_visitor {
    None -> #([], context)
    Some(visitor) ->
      list.fold(module.functions, #([], context), fn(acc, func_def) {
        let function = func_def.definition
        list.fold(function.body, acc, fn(acc2, statement) {
          let #(errors_so_far, ctx) = acc2
          let #(new_errors, new_ctx) = visitor(statement, ctx)
          #(list.append(errors_so_far, new_errors), new_ctx)
        })
      })
  }

  // Run expression visitors (shallow -- just top-level expressions in statements)
  // Full recursive traversal will be in visitor.gleam (Task 2)
  let #(expression_errors, context) = case schema.expression_enter_visitor {
    None -> #([], context)
    Some(visitor) ->
      list.fold(module.functions, #([], context), fn(acc, func_def) {
        let function = func_def.definition
        list.fold(function.body, acc, fn(acc2, statement) {
          let expressions = statement_expressions(statement)
          list.fold(expressions, acc2, fn(acc3, expr_span) {
            let #(expression, span) = expr_span
            let #(errors_so_far, ctx) = acc3
            let #(new_errors, new_ctx) = visitor(expression, span, ctx)
            #(list.append(errors_so_far, new_errors), new_ctx)
          })
        })
      })
  }

  // Run final evaluation
  let #(final_errors, context) = case schema.final_evaluation {
    None -> #([], context)
    Some(evaluator) -> #(evaluator(context), context)
  }

  let all_errors =
    list.flatten([
      import_errors,
      function_errors,
      statement_errors,
      expression_errors,
      final_errors,
    ])

  #(all_errors, context)
}

// --- Internal: extract expressions from a statement (shallow) ---

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
