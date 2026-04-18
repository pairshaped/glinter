# label_possible Suppression for Low-Value Warnings

## Problem

The `label_possible` rule fires on function definitions with unlabeled parameters, but produces noise in cases where labels don't add value:

1. **CPS/callback-style helpers** -- `fn try(result, next)` where the second param is always a continuation
2. **`@external` functions** -- Erlang/JS FFI params can't use labels at the call site
3. **Private micro-helpers** -- small private functions where labeling is ceremony

## Design

### 1. Framework Change: Function Visitors Receive `Definition(Function)`

In `rule.gleam`, change the function visitor field types from:

```
fn(Function, Span, context) -> #(List(RuleError), context)
```

to:

```
fn(Definition(Function), Span, context) -> #(List(RuleError), context)
```

This applies to both `function_visitor` and the simple variant (`with_simple_function_visitor`).

In `run_module_schema_with_context`, instead of extracting `func_def.definition` before passing to the visitor, pass `func_def` (the full `Definition(Function)`) directly. The span still comes from `func_def.definition.location`.

**Impact on existing rules:** All 10 rules using function visitors get a mechanical update -- their visitor callback destructures the `Definition` to pull out the inner `Function`, ignoring `attributes`. No behavior change.

Affected rules:
- `label_possible` (will use the new data)
- `string_inspect`
- `unnecessary_variable`
- `stringly_typed_error`
- `trailing_underscore`
- `assert_ok_pattern`
- `missing_type_annotation`
- `prefer_guard_clause`
- `function_complexity`
- `deep_nesting`
- `module_complexity`

### 2. label_possible Suppression Logic

The rule remains a `with_simple_function_visitor` module rule. Before running the existing parameter-checking logic, it applies three suppression checks in order:

#### Suppression A: `@external` functions

If `definition.attributes` contains `Attribute(name: "external", ...)`, return `[]`. Labels are irrelevant for FFI functions since they can't be used at the call site.

#### Suppression B: Private functions with <= 2 parameters

If `function.publicity == Private` and `list.length(params) <= 2`, return `[]`. Small private helpers are internal API where the author controls both sides; labeling is ceremony.

Private functions with 3+ parameters still get warned -- at that point labels help even the author.

#### Suppression C: Functions with callback parameters

If any parameter has `type_: Some(FunctionType(..))`, skip the entire function (return `[]`). CPS-style helpers are a cohesive pattern where labeling any parameter tends to be noise.

#### Unchanged behavior

If none of the suppressions apply, the existing logic runs: check for >= 2 params, skip functions with unlabeled discards, warn on each unlabeled named parameter.

### 3. Testing

New test cases in `label_possible_test.gleam`:

1. **`@external` suppression:** `@external(erlang, "mod", "fn") fn foo(a: Int, b: Int) -> Int` -- no warnings
2. **Private <= 2 params:** `fn helper(a: Int, b: Int) { a + b }` (no `pub`) -- no warnings
3. **Private 3+ params still warns:** `fn helper(a: Int, b: Int, c: Int) { a + b + c }` -- warnings
4. **Callback param suppression:** `pub fn try_it(result: Result(a, e), next: fn(a) -> b) { todo }` -- no warnings
5. **Existing tests unchanged** -- all use `pub fn` with non-function-type params, pass as-is
