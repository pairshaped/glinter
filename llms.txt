# Glinter Context

Glinter is a linter for Gleam. It parses source files into ASTs using glance and checks them against configurable rules. Rules are based on Gleam conventions. Configuration lives in `gleam.toml`.

## Important: fix first, suppress last

When glinter flags your code, **fix the code first**. Most warnings point to real improvements: better error handling, clearer naming, proper labels. Don't reflexively add `// nolint:` or file-level ignores to make warnings go away. Suppression is for the rare cases where you've considered the warning and the code is intentionally written that way. If you can't explain *why* the suppression is justified, fix the code instead.

## Quick start

```sh
gleam add --dev glinter
gleam run -m glinter
```

Exit code 1 on errors, 0 otherwise. Warnings alone don't fail.

## Configuration

All config goes in `gleam.toml`:

```toml
[tools.glinter]
include = ["src/", "test/"]
exclude = ["src/generated/**/*.gleam"]

[tools.glinter.rules]
avoid_panic = "error"
deep_nesting = "warning"
function_complexity = "off"
# Each rule: "error" | "warning" | "off"
```

## Suppressing warnings

Three levels, from narrowest to broadest. **Use the narrowest scope that covers your case.**

### Line-level: `// nolint:`

Place on its own line directly above the violation. Suppresses that one line only.

```gleam
// nolint: thrown_away_error -- key absent means use default
Error(_) -> Ok([])

// nolint: discarded_result -- fire and forget
let _ = setup()
```

### Function-level: `// nolint:`

Place immediately above `fn` or `pub fn`. Suppresses the listed rules for the entire function body.

```gleam
// nolint: deep_nesting, function_complexity -- recursive AST walker
fn walk_expression(expr, context) {
  // all deep_nesting and function_complexity warnings suppressed here
}
```

### File-level: `gleam.toml`

Suppress rules for entire files. Use when a rule is fundamentally wrong for the file's purpose.

```toml
[tools.glinter.ignore]
"src/cli/*.gleam" = ["stringly_typed_error"]
"test/**/*.gleam" = ["assert_ok_pattern", "missing_type_annotation"]
```

### Stale annotations

Glinter warns (`nolint_unused`) when a `// nolint:` comment doesn't suppress any actual error. Catches orphaned annotations after code changes.

### Inline placement

Glinter warns (`nolint_inline`) when a `// nolint:` comment trails code on the same line. Move it to its own line above the target.

## Rules quick reference

### Error handling
- **avoid_panic** (error): No `panic`. Return `Result` instead.
- **avoid_todo** (error): No `todo`. Finish the code.
- **assert_ok_pattern** (warning): No `let assert` outside `main()`.
- **thrown_away_error** (warning): No `Error(_)`. Propagate or log errors. `Error(_) -> Error(NewError)` (domain conversion) is allowed.
- **discarded_result** (warning): No `let _ = expr`. Handle the Result.
- **error_context_lost** (warning): No `fn(_)` in `result.map_error`. Preserve the original error.
- **stringly_typed_error** (warning): No `Result(x, String)`. Use custom error types.
- **unwrap_used** (off): Flags `result.unwrap`/`option.unwrap`. Off by default.
- **division_by_zero** (error): No `x / 0` or `x % 0`.

### Code quality
- **echo** (warning): No `echo` in production code.
- **panic_without_message** (warning): If you panic, explain why.
- **todo_without_message** (warning): If you todo, explain what's missing.
- **string_inspect** (warning): No `string.inspect`. Use proper serialization.

### Style
- **short_variable_name** (warning): No single-character let bindings.
- **unnecessary_variable** (warning): No `let x = expr; x`. Return directly.
- **redundant_case** (warning): No single-branch case. Use `let`.
- **prefer_guard_clause** (warning): Use `bool.guard` over `case bool { True -> ... False -> ... }`.
- **unnecessary_string_concatenation** (warning): No `x <> ""` or `"foo" <> "bar"`. Mixed literal+variable chains (codegen templates) are allowed.
- **trailing_underscore** (warning): No `fn_name_`. Trailing underscore is for reserved words only.

### Labels
- **label_possible** (warning): Use labels on functions with 2+ params. Suppressed for `@external` functions, private functions with ≤2 params, and functions with callback (`fn(...)`) parameters.
- **missing_labels** (warning): Use defined labels at call sites.

### Types and imports
- **missing_type_annotation** (warning): Annotate return types and parameters.
- **unqualified_import** (warning): Use `mod.func` not `import mod.{func}`.
- **duplicate_import** (warning): Don't import the same module twice.

### Complexity
- **deep_nesting** (warning): Max 5 levels deep.
- **function_complexity** (off): Max 10 branch nodes per function.
- **module_complexity** (off): Max 100 branch nodes per module.

### Cross-module
- **unused_exports** (warning): No unused `pub` declarations. FFI-called functions may false-positive.

### FFI
- **ffi_usage** (off): Flags use of Gleam's internal JS representations in `.mjs` files.

## Smartly suppressed patterns

These patterns don't fire even without `// nolint:` annotations:

- `@external` functions with both erlang + javascript targets: `avoid_panic` and `discarded_result` suppressed in fallback bodies.
- `Error(_) -> Error(NewType)`: `thrown_away_error` recognizes error domain conversion (direct or in blocks).
- Private functions with ≤2 params: `label_possible` suppressed (micro-helper ceremony).
- Functions with `fn(...)` type params: `label_possible` suppressed (CPS/callback pattern).
- `@external` functions: `label_possible` suppressed (labels irrelevant at FFI call sites).
- String concatenation chains mixing literals and variables: `unnecessary_string_concatenation` suppressed (codegen templates).
- `panic` inside exhaustive match on external types: `avoid_panic` suppressed.

## Custom rules

```gleam
import glinter

pub fn main() {
  glinter.run(extra_rules: [my_rules.no_raw_sql()])
}
```

Custom rules use the same builder API as built-in rules. See `src/glinter/rule.gleam`.

## Multi-package projects

Lint each package separately:

```sh
gleam run -m glinter --project server
gleam run -m glinter --project client
gleam run -m glinter --project shared
```
