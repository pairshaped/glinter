# glinter

A linter for the [Gleam](https://gleam.run) programming language. It parses Gleam source files into ASTs using [glance](https://github.com/gleam-community/glance) and checks them against a configurable set of rules. Many rules are based on the official [Gleam conventions](https://gleam.run/documentation/conventions-patterns-and-anti-patterns/#Conventions).

## Installation

```sh
gleam add --dev glinter
```

## Usage

```sh
# Lint the src/ directory (default)
gleam run -m glinter

# Lint specific files or directories
gleam run -m glinter src/myapp/ test/

# JSON output
gleam run -m glinter --format json

# Show stats (files, lines, timing)
gleam run -m glinter --stats

# Lint a different project (resolves gleam.toml and paths relative to project dir)
gleam run -m glinter --project /path/to/my/project
```

The exit code is `1` if any errors are found, `0` otherwise (warnings alone don't fail the run).

### Multi-Package Projects

For monorepos with multiple Gleam packages, add glinter as a dev dependency to one package (e.g. server) and lint each package separately using `--project`:

```sh
# From any directory, lint each package
gleam run -m glinter --project server
gleam run -m glinter --project client
gleam run -m glinter --project shared
```

Each package uses its own `gleam.toml` for configuration. You can wrap this in a script to lint all packages at once:

```sh
#!/bin/sh
# bin/lint
set -e
for pkg in server client shared; do
  echo "Linting $pkg..."
  gleam run -m glinter --project "$pkg"
done
```

## Rules

### Error Handling

These rules enforce explicit error handling. Gleam's `Result` type exists so errors are handled at every level, not silently discarded.

- **assert_ok_pattern** (warning): flags `let assert` outside of `main()`. Functions should return `Result` and let the caller decide how to handle errors. Only `main()` — the application entry point — should crash on failure, because that's startup code where crash-on-failure is the correct behavior. This pushes error handling to the right level and prevents request handlers or library code from crashing the process.

- **error_context_lost** (warning): flags `result.map_error` calls where the callback discards the original error with `fn(_) { ... }`. The original error carries context about what went wrong. Note: `result.replace_error` is not flagged — it's the correct tool for upgrading `Nil` errors into domain errors.

- **thrown_away_error** (warning): flags `Error(_)` patterns in case expressions that discard the error value. Propagate errors with `result.try`, use `result.or` for fallback chains, or log at system boundaries. If the error is `Nil`, match `Error(Nil)` explicitly.

- **stringly_typed_error** (warning): flags functions with `Result(x, String)` return types. String errors can't be pattern matched by callers — use a custom error type instead.

- **discarded_result** (warning): flags `let _ = expr` where the expression likely returns a Result. Silently discarding Results hides failures.

- **unwrap_used** (off): flags `result.unwrap`, `option.unwrap`, and lazy variants. Off by default because `unwrap` with an intentional default (optional config, end of fallback chain) is legitimate. Enable for stricter codebases. The planned error-flow tracking rule will catch the dangerous cases (silently discarding meaningful errors) more precisely.

- **division_by_zero** (error): flags division or remainder by literal zero (`x / 0`, `x /. 0.0`, `x % 0`). Gleam doesn't crash on division by zero — it silently returns 0, which produces wrong results. This catches literal zero divisors only; variable divisors require runtime checks.

### Code Quality

These rules catch debug artifacts and patterns that shouldn't ship to production.

- **avoid_panic** (error): flags uses of `panic`. Panics crash the process. Return `Result` instead, and let `main()` decide what's fatal.
- **avoid_todo** (error): flags uses of `todo`. Unfinished code shouldn't be committed.
- **echo** (warning): flags uses of `echo`. Debug output left in production code.
- **panic_without_message** (warning): flags `panic` without a descriptive message. If you must panic, explain why.
- **todo_without_message** (warning): flags `todo` without a descriptive message. Explain what's missing.
- **string_inspect** (warning): flags `string.inspect` usage. Typically debug output — use proper serialization instead.

### Style

These rules enforce consistency and catch patterns that make code harder to read.

- **short_variable_name** (warning): flags single-character variable names in let bindings. Use descriptive names.
- **unnecessary_variable** (warning): flags `let x = expr; x` — assigned then immediately returned. Just return the expression directly.
- **redundant_case** (warning): flags `case` expressions with a single branch and no guard. Use `let` instead.
- **prefer_guard_clause** (warning): flags `case bool { True -> ... False -> ... }` patterns that could use `bool.guard`.
- **unnecessary_string_concatenation** (warning): flags concatenation with an empty string (`x <> ""`) and concatenation of two string literals (`"foo" <> "bar"`).
- **trailing_underscore** (warning): flags function names ending with `_`. Gleam uses trailing underscore for reserved word conflicts (`type_`), not as a naming convention.

### Type Annotations

- **missing_type_annotation** (warning): flags functions missing return type annotations or with untyped parameters. Explicit types make code self-documenting and catch errors earlier.

### Complexity

- **deep_nesting** (warning): flags nesting deeper than 5 levels. Deeply nested code is hard to follow — extract helper functions.
- **function_complexity** (off): flags functions with more than 10 branching nodes. Off by default — branch count doesn't correlate with readability (routers, state machines, parsers are naturally branchy). Enable with `function_complexity = "warning"`.
- **module_complexity** (off): flags modules with more than 100 total branching nodes. Off by default — [large cohesive modules are idiomatic Gleam](https://gleam.run/documentation/conventions-patterns-and-anti-patterns/#Fragmented-modules). Enable with `module_complexity = "warning"`.

### Labels

- **label_possible** (warning): flags unlabeled parameters in functions with 2+ parameters. Labels make call sites self-documenting and have zero runtime cost in Gleam.
- **missing_labels** (warning): flags calls to same-module functions that omit defined labels. If the function defines labels, use them.

### Imports

- **unqualified_import** (warning): flags unqualified function/constant imports (e.g. `import mod.{func}`). Gleam convention is to use qualified access (`mod.func`). Constructor imports (`Some`, `None`, `Ok`, etc.) and type imports are not flagged.
- **duplicate_import** (warning): flags importing the same module more than once in a file.

### Cross-Module

- **unused_exports** (warning): flags `pub` functions, constants, and types never referenced from another module. Test files count as consumers, `main` is excluded. Note: Gleam has FFI boundaries — functions called from Erlang/JS code outside the project may be flagged as unused.

### FFI

- **ffi_usage** (off): flags use of Gleam's private JS data API in `.mjs` files — numeric property access (`value[0]`, `tuple.0`), internal constructor checks (`$constructor`), runtime imports (`gleam.mjs`), and internal helpers (`makeError`, `isEqual`, `CustomType`, etc.). These representations can change between compiler versions. Off by default — enable if your project includes JS FFI.

## Configuration

Configuration lives in your project's `gleam.toml` under the `[tools.glinter]` key:

```toml
[tools.glinter]
stats = true  # show file count, line count, and timing after each run
warnings_as_errors = true  # promote all warnings to errors (exit 1 on any issue)
include = ["src/", "test/"]  # directories to lint (default: ["src/"])
exclude = ["src/server/sql.gleam"]  # skip generated files entirely

[tools.glinter.rules]
avoid_panic = "error"
avoid_todo = "error"
echo = "warning"
assert_ok_pattern = "warning"
discarded_result = "warning"
short_variable_name = "warning"
unnecessary_variable = "warning"
redundant_case = "warning"
unwrap_used = "warning"
deep_nesting = "warning"
function_complexity = "off"  # off by default
module_complexity = "off"  # off by default
prefer_guard_clause = "warning"
missing_labels = "warning"
label_possible = "warning"
unused_exports = "warning"
missing_type_annotation = "warning"
todo_without_message = "warning"
unqualified_import = "warning"
panic_without_message = "warning"
string_inspect = "warning"
duplicate_import = "warning"
unnecessary_string_concatenation = "warning"
trailing_underscore = "warning"
error_context_lost = "warning"
stringly_typed_error = "warning"
thrown_away_error = "warning"
ffi_usage = "off"  # off by default
```

Each rule can be set to `"error"`, `"warning"`, or `"off"`.

### Excluding Files

Skip files entirely (useful for generated code). Supports globs:

```toml
[tools.glinter]
exclude = ["src/server/sql.gleam", "src/generated/**/*.gleam"]
```

### Ignoring Rules Per File

Suppress specific rules for files where they don't make sense. Also supports globs:

```toml
[tools.glinter.ignore]
"src/my_complex_module.gleam" = ["deep_nesting", "function_complexity"]
"test/**/*.gleam" = ["assert_ok_pattern", "short_variable_name", "missing_type_annotation", "label_possible", "missing_labels", "unqualified_import"]
```

### Suppressing Warnings with Comments

Use `// nolint:` comments for targeted suppression. **Fix the code first** — only suppress when the violation is intentional.

Three levels, from narrowest to broadest. **Use the narrowest scope that covers your case.**

#### Line-level

Place the comment on the line directly above the code it suppresses, or inline on the same line:

```gleam
// nolint: thrown_away_error -- key absent means use default
Error(_) -> Ok([])

let _ = setup() // nolint: discarded_result -- fire and forget
```

#### Function-level

Place the comment directly above `fn` or `pub fn` (no blank lines between). Suppresses the listed rules for the entire function body:

```gleam
// nolint: deep_nesting, function_complexity -- recursive AST walker
fn walk_expression(expr, context) {
  // all deep_nesting and function_complexity warnings suppressed here
}
```

#### Optional reason

Add `--` after the rule list to explain why:

```gleam
// nolint: avoid_panic -- fallback body is unreachable with dual @external
```

#### Stale annotation detection

Glinter warns (`nolint_unused`) when a `// nolint:` annotation:
- Isn't followed by code (blank line, another comment, or end of file)
- Doesn't suppress any actual warning (code was fixed but annotation wasn't removed)

## Output Formats

### Text (default)

```
src/app.gleam:12: [error] avoid_panic: Use of 'panic' is discouraged
src/app.gleam:25: [warning] echo: Use of 'echo' is discouraged
```

### JSON

```sh
gleam run -m glinter --format json
```

```json
{
  "results": [
    {
      "rule": "avoid_panic",
      "severity": "error",
      "file": "src/app.gleam",
      "line": 12,
      "message": "Use of 'panic' is discouraged"
    }
  ],
  "summary": {
    "total": 1,
    "errors": 1,
    "warnings": 0
  }
}
```

When `--stats` is enabled, a `stats` object is included:

```json
{
  "stats": {
    "files": 23,
    "lines": 2544,
    "elapsed_ms": 45
  }
}
```

## Custom Rules (Plugins)

Add project-specific rules by calling `glinter.run` with extra rules from your own packages:

```gleam
// test/review.gleam
import glinter
import my_project/rules

pub fn main() {
  glinter.run(extra_rules: [
    rules.no_raw_sql(),
    rules.require_org_id_filter(),
  ])
}
```

```sh
gleam run -m review
```

Custom rules use the same builder API as built-in rules and get the same config treatment (on/off/severity in `gleam.toml`, file-level ignores). See `src/glinter/rule.gleam` for the API.

If you write a rule that would be useful to the broader Gleam community, PRs are welcome. Contributed rules can ship with a default severity of `off` so projects opt in explicitly.

## Running Tests

```sh
gleam test
```

## License

MIT
