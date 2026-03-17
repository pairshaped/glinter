import glance
import gleam/list
import glinter/rule

// --- Test 1: Simple module rule builder ---

pub fn simple_module_rule_name_test() {
  let r =
    rule.new(name: "my_rule")
    |> rule.with_simple_expression_visitor(visitor: fn(_expr, _span) { [] })
    |> rule.to_module_rule()

  let assert True = rule.name(r) == "my_rule"
}

pub fn simple_module_rule_is_not_project_rule_test() {
  let r =
    rule.new(name: "my_rule")
    |> rule.to_module_rule()

  let assert True = rule.is_project_rule(r) == False
}

pub fn simple_module_rule_default_severity_is_warning_test() {
  let r =
    rule.new(name: "my_rule")
    |> rule.to_module_rule()

  let assert True = rule.default_severity(r) == rule.Warning
}

// --- Test 2: Stateful module rule builder ---

pub fn stateful_module_rule_builds_test() {
  let r =
    rule.new_with_context(name: "stateful_rule", initial: 0)
    |> rule.with_expression_enter_visitor(visitor: fn(_expr, _span, count) {
      #([], count + 1)
    })
    |> rule.with_final_evaluation(evaluator: fn(count) {
      case count > 0 {
        True -> [
          rule.error(
            message: "Found expressions",
            details: "",
            location: glance.Span(start: 0, end: 0),
          ),
        ]
        False -> []
      }
    })
    |> rule.to_module_rule()

  let assert True = rule.name(r) == "stateful_rule"
  let assert True = rule.is_project_rule(r) == False
}

// --- Test 3: Project rule builder ---

pub fn project_rule_builds_test() {
  let r =
    rule.new_project(name: "project_rule", initial: [])
    |> rule.with_module_visitor(builder: fn(schema) {
      schema
      |> rule.with_simple_import_visitor(visitor: fn(import_def) {
        let glance.Definition(_, import_) = import_def
        case import_.module {
          "gleam/io" -> [
            rule.error(
              message: "Don't use gleam/io",
              details: "",
              location: import_.location,
            ),
          ]
          _ -> []
        }
      })
    })
    |> rule.with_module_context(
      from_project_to_module: fn(_pc) { Nil },
      from_module_to_project: fn(_mc, pc) { pc },
      fold_project_contexts: fn(a, _b) { a },
    )
    |> rule.with_final_project_evaluation(evaluator: fn(_pc) { [] })
    |> rule.to_project_rule()

  let assert True = rule.name(r) == "project_rule"
  let assert True = rule.is_project_rule(r) == True
}

// --- Test 4: Error constructor ---

pub fn error_constructor_test() {
  let err =
    rule.error(
      message: "bad thing",
      details: "more info",
      location: glance.Span(start: 10, end: 20),
    )

  let assert True = rule.error_message(err) == "bad thing"
  let assert True = rule.error_details(err) == "more info"
  let assert True = rule.error_location(err) == glance.Span(start: 10, end: 20)
}

// --- Test 5: run_on_module with a simple rule ---

pub fn run_module_rule_finds_panic_test() {
  let r =
    rule.new(name: "no_panic")
    |> rule.with_simple_expression_visitor(visitor: fn(expression, span) {
      case expression {
        glance.Panic(..) -> [
          rule.error(message: "Don't use panic", details: "", location: span),
        ]
        _ -> []
      }
    })
    |> rule.to_module_rule()

  let assert Ok(module) = glance.module("pub fn bad() { panic }")
  let errors = rule.run_on_module(rule: r, module: module, source: "")
  let assert True = list.length(errors) == 1
  let assert [err] = errors
  let assert True = rule.error_message(err) == "Don't use panic"
}

pub fn run_module_rule_no_errors_on_clean_code_test() {
  let r =
    rule.new(name: "no_panic")
    |> rule.with_simple_expression_visitor(visitor: fn(expression, span) {
      case expression {
        glance.Panic(..) -> [
          rule.error(message: "Don't use panic", details: "", location: span),
        ]
        _ -> []
      }
    })
    |> rule.to_module_rule()

  let assert Ok(module) = glance.module("pub fn good() { 1 }")
  let errors = rule.run_on_module(rule: r, module: module, source: "")
  let assert True = errors == []
}

// --- Test: run_on_module with import visitor ---

pub fn run_module_rule_with_import_visitor_test() {
  let r =
    rule.new(name: "no_io")
    |> rule.with_simple_import_visitor(visitor: fn(import_def) {
      let glance.Definition(_, import_) = import_def
      case import_.module {
        "gleam/io" -> [
          rule.error(
            message: "Don't import gleam/io",
            details: "",
            location: import_.location,
          ),
        ]
        _ -> []
      }
    })
    |> rule.to_module_rule()

  let assert Ok(module) = glance.module("import gleam/io\npub fn main() { 1 }")
  let errors = rule.run_on_module(rule: r, module: module, source: "")
  let assert True = list.length(errors) == 1
}

// --- Test: stateful rule accumulates context ---

pub fn stateful_rule_accumulates_context_test() {
  let r =
    rule.new_with_context(name: "count_functions", initial: 0)
    |> rule.with_function_visitor(visitor: fn(_function, _span, count) {
      #([], count + 1)
    })
    |> rule.with_final_evaluation(evaluator: fn(count) {
      case count > 2 {
        True -> [
          rule.error(
            message: "Too many functions",
            details: "",
            location: glance.Span(start: 0, end: 0),
          ),
        ]
        False -> []
      }
    })
    |> rule.to_module_rule()

  // 3 functions -- should trigger
  let source = "pub fn a() { 1 }\npub fn b() { 2 }\npub fn c() { 3 }"
  let assert Ok(module) = glance.module(source)
  let errors = rule.run_on_module(rule: r, module: module, source: source)
  let assert True = list.length(errors) == 1

  // 2 functions -- should not trigger
  let source2 = "pub fn a() { 1 }\npub fn b() { 2 }"
  let assert Ok(module2) = glance.module(source2)
  let errors2 = rule.run_on_module(rule: r, module: module2, source: source2)
  let assert True = errors2 == []
}

// --- Test: run_on_module returns empty for project rules ---

pub fn run_on_module_returns_empty_for_project_rule_test() {
  let r =
    rule.new_project(name: "project_only", initial: Nil)
    |> rule.to_project_rule()

  let assert Ok(module) = glance.module("pub fn main() { 1 }")
  let errors = rule.run_on_module(rule: r, module: module, source: "")
  let assert True = errors == []
}

// --- Test: run_on_project returns empty for module rules ---

pub fn run_on_project_returns_empty_for_module_rule_test() {
  let r =
    rule.new(name: "module_only")
    |> rule.to_module_rule()

  let errors = rule.run_on_project(rule: r, files: [])
  let assert True = errors == []
}

// --- Test: project rule runs across files ---

pub fn project_rule_runs_across_files_test() {
  let r =
    rule.new_project(name: "count_all_imports", initial: 0)
    |> rule.with_module_visitor(builder: fn(schema) {
      schema
      |> rule.with_import_visitor(visitor: fn(_import_def, count) {
        #([], count + 1)
      })
    })
    |> rule.with_module_context(
      from_project_to_module: fn(pc) { pc },
      from_module_to_project: fn(mc, _pc) { mc },
      fold_project_contexts: fn(a, b) { a + b },
    )
    |> rule.with_final_project_evaluation(evaluator: fn(total) {
      case total > 2 {
        True -> [
          rule.error(
            message: "Too many imports across project",
            details: "",
            location: glance.Span(start: 0, end: 0),
          ),
        ]
        False -> []
      }
    })
    |> rule.to_project_rule()

  // File 1 has 2 imports, file 2 has 1 import = 3 total > 2
  let assert Ok(module1) =
    glance.module("import gleam/list\nimport gleam/int\npub fn a() { 1 }")
  let assert Ok(module2) =
    glance.module("import gleam/string\npub fn b() { 1 }")

  let errors =
    rule.run_on_project(rule: r, files: [
      #(module1, "file1.gleam"),
      #(module2, "file2.gleam"),
    ])
  let assert True = list.length(errors) == 1
  let assert [err] = errors
  let assert True = rule.error_message(err) == "Too many imports across project"
}
