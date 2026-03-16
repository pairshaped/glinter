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

The exit code is `1` if any issues are found, `0` otherwise.

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

### Code Quality

- **avoid_panic** (error): flags uses of `panic`
- **avoid_todo** (error): flags uses of `todo`
- **echo** (warning): flags uses of `echo` (debug output)
- **assert_ok_pattern** (warning): flags `let assert` assignments
- **unwrap_used** (warning): flags `result.unwrap`, `option.unwrap`, and lazy variants
- **todo_without_message** (warning): flags `todo` without a descriptive message
- **panic_without_message** (warning): flags `panic` without a descriptive message
- **string_inspect** (warning): flags `string.inspect` usage (debug output)

### Error Handling

- **error_context_lost** (warning): flags `result.replace_error` (which always discards the original error) and `result.map_error` calls where the callback discards the original error with `fn(_) { ... }`
- **stringly_typed_error** (warning): flags functions with `Result(x, String)` return types — use a custom error type instead
- **thrown_away_error** (warning): flags `Error(_)` patterns in case expressions that discard the error value. Can be noisy in codebases with many fallback patterns — disable with `thrown_away_error = "off"` in config.

### Type Annotations

- **missing_type_annotation** (warning): flags functions missing return type annotations or with untyped parameters

### Style

- **discarded_result** (warning): flags `let _ = expr` (discarded results)
- **short_variable_name** (warning): flags single-character variable names in let bindings
- **unnecessary_variable** (warning): flags `let x = expr; x` (assigned then immediately returned)
- **redundant_case** (warning): flags `case` expressions with a single branch and no guard
- **prefer_guard_clause** (warning): flags `case bool { True -> ... False -> ... }` patterns that could use `bool.guard`
- **unnecessary_string_concatenation** (warning): flags concatenation with an empty string (`x <> ""`) and concatenation of two string literals (`"foo" <> "bar"`)
- **trailing_underscore** (warning): flags function names ending with `_`

### Complexity

- **deep_nesting** (warning): flags nesting deeper than 5 levels
- **function_complexity** (off): flags functions with more than 10 branching nodes. Off by default — branch count doesn't correlate with readability (routers, state machines, parsers are naturally branchy). Enable with `function_complexity = "warning"` in config.
- **module_complexity** (off): flags modules with more than 100 total branching nodes. Off by default — [large cohesive modules are idiomatic Gleam](https://gleam.run/documentation/conventions-patterns-and-anti-patterns/#Fragmented-modules). Enable with `module_complexity = "warning"` in config.

### Labels

- **label_possible** (warning): flags unlabeled parameters in functions with 2+ parameters
- **missing_labels** (warning): flags calls to same-module functions that omit defined labels

### Imports

- **unqualified_import** (warning): flags unqualified function/constant imports (e.g. `import mod.{func}`). Gleam convention is to use qualified access (`mod.func`). Constructor imports (`Some`, `None`, `Ok`, etc.) and type imports are not flagged.
- **duplicate_import** (warning): flags importing the same module more than once in a file

### Cross-Module

- **unused_exports** (warning): flags `pub` functions, constants, and types never referenced from another module. Test files count as consumers, `main` is excluded.

### FFI

- **ffi_usage** (off): flags use of Gleam's private JS data API in `.mjs` files — numeric property access (`value[0]`, `tuple.0`), internal constructor checks (`$constructor`), runtime imports (`gleam.mjs`), and internal helpers (`makeError`, `isEqual`, `CustomType`, etc.). These representations can change between compiler versions. Off by default — enable if your project includes JS FFI. Scans `.mjs` files in configured source directories only. Community feedback and PRs welcome to improve pattern detection.

## Configuration

Configuration lives in your project's `gleam.toml` under the `[tools.glinter]` key:

```toml
[tools.glinter]
stats = true  # show file count, line count, and timing after each run
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

## Running Tests

```sh
gleam test
```

## License

MIT
