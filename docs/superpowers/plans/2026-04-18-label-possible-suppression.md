# label_possible Suppression Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Reduce false-positive noise from `label_possible` by suppressing warnings for `@external` functions, small private helpers, and CPS/callback-style functions.

**Architecture:** Two changes: (1) extend the function visitor in `rule.gleam` to pass `Definition(Function)` instead of bare `Function`, giving all function visitor rules access to attributes and the definition wrapper; (2) add three suppression checks to `label_possible` using the newly available data.

**Tech Stack:** Gleam, glance (AST parser)

---

### Task 1: Update function visitor type in rule.gleam

**Files:**
- Modify: `src/glinter/rule.gleam:57-58` (ModuleRuleSchema field type)
- Modify: `src/glinter/rule.gleam:189-195` (with_function_visitor signature)
- Modify: `src/glinter/rule.gleam:226-235` (with_simple_function_visitor signature)
- Modify: `src/glinter/rule.gleam:499-502` (visitor call site in run_module_schema_with_context)

- [ ] **Step 1: Update the function_visitor field type in ModuleRuleSchema**

In `src/glinter/rule.gleam`, change lines 57-58 from:

```gleam
    function_visitor: Option(
      fn(glance.Function, glance.Span, context) -> #(List(RuleError), context),
    ),
```

to:

```gleam
    function_visitor: Option(
      fn(glance.Definition(glance.Function), glance.Span, context) ->
        #(List(RuleError), context),
    ),
```

- [ ] **Step 2: Update with_function_visitor signature**

In `src/glinter/rule.gleam`, change lines 189-195 from:

```gleam
pub fn with_function_visitor(
  schema schema: ModuleRuleSchema(context),
  visitor visitor: fn(glance.Function, glance.Span, context) ->
    #(List(RuleError), context),
) -> ModuleRuleSchema(context) {
  ModuleRuleSchema(..schema, function_visitor: Some(visitor))
}
```

to:

```gleam
pub fn with_function_visitor(
  schema schema: ModuleRuleSchema(context),
  visitor visitor: fn(glance.Definition(glance.Function), glance.Span, context) ->
    #(List(RuleError), context),
) -> ModuleRuleSchema(context) {
  ModuleRuleSchema(..schema, function_visitor: Some(visitor))
}
```

- [ ] **Step 3: Update with_simple_function_visitor signature**

In `src/glinter/rule.gleam`, change lines 226-235 from:

```gleam
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
```

to:

```gleam
pub fn with_simple_function_visitor(
  schema schema: ModuleRuleSchema(context),
  visitor visitor: fn(glance.Definition(glance.Function), glance.Span) ->
    List(RuleError),
) -> ModuleRuleSchema(context) {
  ModuleRuleSchema(
    ..schema,
    function_visitor: Some(fn(definition, span, ctx) {
      #(visitor(definition, span), ctx)
    }),
  )
```

- [ ] **Step 4: Update the visitor call site in run_module_schema_with_context**

In `src/glinter/rule.gleam`, change lines 496-502 from:

```gleam
      let #(errors_so_far, ctx) = acc
      let function = func_def.definition

      // 2a. Call function visitor
      let #(fn_errors, ctx) = case schema.function_visitor {
        None -> #([], ctx)
        Some(visitor) -> visitor(function, function.location, ctx)
      }
```

to:

```gleam
      let #(errors_so_far, ctx) = acc

      // 2a. Call function visitor
      let #(fn_errors, ctx) = case schema.function_visitor {
        None -> #([], ctx)
        Some(visitor) ->
          visitor(func_def, func_def.definition.location, ctx)
      }
```

Note: `func_def.definition` is still used on line 507 for `function.body` -- keep that reference. Update line 507 from `visit_statements(schema, function.body, #([], ctx))` to `visit_statements(schema, func_def.definition.body, #([], ctx))`.

- [ ] **Step 5: Verify it compiles (expect errors from downstream rules)**

Run: `gleam build 2>&1 | head -40`
Expected: Compile errors in the 10 rules that use function visitors (type mismatch on the callback argument). This confirms the framework change propagated correctly.

---

### Task 2: Update all existing function visitor callbacks

**Files:**
- Modify: `src/glinter/rules/string_inspect.gleam:21-25`
- Modify: `src/glinter/rules/unnecessary_variable.gleam:12-15`
- Modify: `src/glinter/rules/stringly_typed_error.gleam:11-14`
- Modify: `src/glinter/rules/trailing_underscore.gleam:11-14`
- Modify: `src/glinter/rules/assert_ok_pattern.gleam:19-25`
- Modify: `src/glinter/rules/missing_type_annotation.gleam:12-15`
- Modify: `src/glinter/rules/prefer_guard_clause.gleam:12-15`
- Modify: `src/glinter/rules/function_complexity.gleam:15-18`
- Modify: `src/glinter/rules/deep_nesting.gleam:21-27`
- Modify: `src/glinter/rules/module_complexity.gleam:23-30`

Each rule needs its visitor callback updated to accept `glance.Definition(glance.Function)` and destructure to get the inner `Function`. The pattern is the same for all:

**For simple visitors** (accept `glance.Function, glance.Span`): change to accept `glance.Definition(glance.Function), glance.Span`, add `let function = definition.definition` as the first line.

**For stateful visitors** (accept `glance.Function, glance.Span, Context`): change to accept `glance.Definition(glance.Function), glance.Span, Context`, add `let function = definition.definition` as the first line.

- [ ] **Step 1: Update string_inspect.gleam**

Change:

```gleam
fn collect_generic_params(
  function: glance.Function,
  _span: glance.Span,
  _context: Context,
) -> #(List(rule.RuleError), Context) {
```

to:

```gleam
fn collect_generic_params(
  definition: glance.Definition(glance.Function),
  _span: glance.Span,
  _context: Context,
) -> #(List(rule.RuleError), Context) {
  let function = definition.definition
```

- [ ] **Step 2: Update unnecessary_variable.gleam**

Change:

```gleam
fn check_function(
  function: glance.Function,
  _span: glance.Span,
) -> List(rule.RuleError) {
```

to:

```gleam
fn check_function(
  definition: glance.Definition(glance.Function),
  _span: glance.Span,
) -> List(rule.RuleError) {
  let function = definition.definition
```

- [ ] **Step 3: Update stringly_typed_error.gleam**

Change:

```gleam
fn check_function(
  function: glance.Function,
  span: glance.Span,
) -> List(rule.RuleError) {
```

to:

```gleam
fn check_function(
  definition: glance.Definition(glance.Function),
  span: glance.Span,
) -> List(rule.RuleError) {
  let function = definition.definition
```

- [ ] **Step 4: Update trailing_underscore.gleam**

Change:

```gleam
fn check_function(
  function: glance.Function,
  span: glance.Span,
) -> List(rule.RuleError) {
```

to:

```gleam
fn check_function(
  definition: glance.Definition(glance.Function),
  span: glance.Span,
) -> List(rule.RuleError) {
  let function = definition.definition
```

- [ ] **Step 5: Update assert_ok_pattern.gleam**

Change:

```gleam
fn track_function(
  function: glance.Function,
  _span: glance.Span,
  _context: Context,
) -> #(List(rule.RuleError), Context) {
```

to:

```gleam
fn track_function(
  definition: glance.Definition(glance.Function),
  _span: glance.Span,
  _context: Context,
) -> #(List(rule.RuleError), Context) {
  let function = definition.definition
```

- [ ] **Step 6: Update missing_type_annotation.gleam**

Change:

```gleam
fn check_function(
  function: glance.Function,
  span: glance.Span,
) -> List(rule.RuleError) {
```

to:

```gleam
fn check_function(
  definition: glance.Definition(glance.Function),
  span: glance.Span,
) -> List(rule.RuleError) {
  let function = definition.definition
```

- [ ] **Step 7: Update prefer_guard_clause.gleam**

Change:

```gleam
fn check_function(
  function: glance.Function,
  _span: glance.Span,
) -> List(rule.RuleError) {
```

to:

```gleam
fn check_function(
  definition: glance.Definition(glance.Function),
  _span: glance.Span,
) -> List(rule.RuleError) {
  let function = definition.definition
```

- [ ] **Step 8: Update function_complexity.gleam**

Change:

```gleam
fn check_function(
  function: glance.Function,
  span: glance.Span,
) -> List(rule.RuleError) {
```

to:

```gleam
fn check_function(
  definition: glance.Definition(glance.Function),
  span: glance.Span,
) -> List(rule.RuleError) {
  let function = definition.definition
```

- [ ] **Step 9: Update deep_nesting.gleam**

Change:

```gleam
fn on_function(
  _function: glance.Function,
  _span: glance.Span,
  _context: Context,
) -> #(List(rule.RuleError), Context) {
```

to:

```gleam
fn on_function(
  _definition: glance.Definition(glance.Function),
  _span: glance.Span,
  _context: Context,
) -> #(List(rule.RuleError), Context) {
```

Note: `deep_nesting` doesn't use the function argument at all (it's `_function`), so no `let function = ...` line is needed. Just change the parameter name and type.

- [ ] **Step 10: Update module_complexity.gleam**

Change:

```gleam
fn count_function(
  function: glance.Function,
  _span: glance.Span,
  context: Context,
) -> #(List(rule.RuleError), Context) {
```

to:

```gleam
fn count_function(
  definition: glance.Definition(glance.Function),
  _span: glance.Span,
  context: Context,
) -> #(List(rule.RuleError), Context) {
  let function = definition.definition
```

- [ ] **Step 11: Build and run all tests**

Run: `gleam test 2>&1`
Expected: All existing tests pass. No behavior change.

- [ ] **Step 12: Commit**

```bash
git add src/glinter/rule.gleam src/glinter/rules/string_inspect.gleam src/glinter/rules/unnecessary_variable.gleam src/glinter/rules/stringly_typed_error.gleam src/glinter/rules/trailing_underscore.gleam src/glinter/rules/assert_ok_pattern.gleam src/glinter/rules/missing_type_annotation.gleam src/glinter/rules/prefer_guard_clause.gleam src/glinter/rules/function_complexity.gleam src/glinter/rules/deep_nesting.gleam src/glinter/rules/module_complexity.gleam
git commit -m "Pass Definition(Function) to function visitors

Extend the function visitor in rule.gleam to pass the full
Definition wrapper instead of bare Function. This gives all
function visitor rules access to attributes (e.g. @external).
Update all 10 existing function visitor callbacks to match."
```

---

### Task 3: Write failing tests for label_possible suppressions

**Files:**
- Modify: `test/glinter/rules/label_possible_test.gleam`

- [ ] **Step 1: Add test for @external suppression**

Append to `test/glinter/rules/label_possible_test.gleam`:

```gleam
pub fn ignores_external_function_test() {
  let results =
    test_helpers.lint_string_rule(
      "@external(erlang, \"mymod\", \"myfn\")
pub fn my_external(a: Int, b: Int) -> Int",
      label_possible.rule(),
    )
  let assert True = results == []
}
```

- [ ] **Step 2: Add test for private function with 2 params**

```gleam
pub fn ignores_private_function_with_two_params_test() {
  let results =
    test_helpers.lint_string_rule(
      "fn helper(a: Int, b: Int) { a + b }",
      label_possible.rule(),
    )
  let assert True = results == []
}
```

- [ ] **Step 3: Add test for private function with 3+ params still warns**

```gleam
pub fn detects_private_function_with_three_params_test() {
  let results =
    test_helpers.lint_string_rule(
      "fn helper(a: Int, b: Int, c: Int) { a + b + c }",
      label_possible.rule(),
    )
  let assert True = list.length(results) == 3
}
```

- [ ] **Step 4: Add test for callback parameter suppression**

```gleam
pub fn ignores_function_with_callback_param_test() {
  let results =
    test_helpers.lint_string_rule(
      "pub fn try_it(result: Result(a, e), next: fn(a) -> b) { todo }",
      label_possible.rule(),
    )
  let assert True = results == []
}
```

- [ ] **Step 5: Run the new tests to verify they fail**

Run: `gleam test 2>&1 | grep -E "label_possible|FAIL|Matched"`
Expected: The 3 suppression tests fail (they currently produce warnings). The "private 3+ params" test should already pass since the existing logic warns on those.

---

### Task 4: Implement label_possible suppressions

**Files:**
- Modify: `src/glinter/rules/label_possible.gleam`

- [ ] **Step 1: Update the visitor signature and add suppression logic**

Replace the entire contents of `src/glinter/rules/label_possible.gleam` with:

```gleam
import glance
import gleam/list
import gleam/option.{None, Some}
import glinter/rule

pub fn rule() -> rule.Rule {
  rule.new(name: "label_possible")
  |> rule.with_simple_function_visitor(visitor: check_function)
  |> rule.to_module_rule()
}

fn check_function(
  definition: glance.Definition(glance.Function),
  span: glance.Span,
) -> List(rule.RuleError) {
  let function = definition.definition
  let params = function.parameters

  // Suppression: @external functions (labels can't be used at FFI call sites)
  let is_external =
    list.any(definition.attributes, fn(attr) { attr.name == "external" })
  case is_external {
    True -> []
    False -> {
      // Suppression: private functions with <= 2 params (micro-helper ceremony)
      let is_private = function.publicity == glance.Private
      case is_private && list.length(params) <= 2 {
        True -> []
        False -> {
          // Suppression: any param is a function type (CPS/callback pattern)
          let has_callback_param =
            list.any(params, fn(param) {
              case param.type_ {
                Some(glance.FunctionType(..)) -> True
                _ -> False
              }
            })
          case has_callback_param {
            True -> []
            False -> check_params(params, span)
          }
        }
      }
    }
  }
}

fn check_params(
  params: List(glance.FunctionParameter),
  span: glance.Span,
) -> List(rule.RuleError) {
  // Skip functions with fewer than 2 params, or any unlabelled discard param
  // (you can't fully label a function that has an unlabelled discard)
  let has_unlabelled_discard =
    list.any(params, fn(param) {
      param.label == None
      && case param.name {
        glance.Discarded(_) -> True
        glance.Named(_) -> False
      }
    })
  case list.length(params) >= 2 && !has_unlabelled_discard {
    False -> []
    True ->
      params
      |> list.filter(fn(param) { param.label == None })
      |> list.map(fn(param) {
        let assert glance.Named(name) = param.name
        rule.error(
          message: "Parameter '"
            <> name
            <> "' could benefit from a label for clarity at call sites",
          details: "Labelled arguments make call sites self-documenting with zero performance cost.",
          location: span,
        )
      })
  }
}
```

- [ ] **Step 2: Run all tests**

Run: `gleam test 2>&1`
Expected: All tests pass, including the 4 new ones and all 6 existing ones.

- [ ] **Step 3: Commit**

```bash
git add src/glinter/rules/label_possible.gleam test/glinter/rules/label_possible_test.gleam
git commit -m "Suppress label_possible for external, private, and callback functions

Skip warning when:
- Function has @external attribute (labels irrelevant for FFI)
- Function is private with <= 2 params (micro-helper ceremony)
- Any parameter has a function type (CPS/callback pattern)"
```
