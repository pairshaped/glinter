# glinter

A linter for the [Gleam](https://gleam.run) programming language. It parses Gleam source files into ASTs using [glance](https://github.com/gleam-community/glance) and checks them against a configurable set of rules.

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

### Type Annotations

- **missing_type_annotation** (warning): flags functions missing return type annotations or with untyped parameters

### Style

- **discarded_result** (warning): flags `let _ = expr` (discarded results)
- **short_variable_name** (warning): flags single-character variable names in let bindings
- **unnecessary_variable** (warning): flags `let x = expr; x` (assigned then immediately returned)
- **redundant_case** (warning): flags `case` expressions with a single branch and no guard
- **prefer_guard_clause** (warning): flags `case bool { True -> ... False -> ... }` patterns that could use `bool.guard`

### Complexity

- **deep_nesting** (warning): flags nesting deeper than 5 levels
- **function_complexity** (warning): flags functions with more than 10 branching nodes
- **module_complexity** (warning): flags modules with more than 50 total branching nodes

### Labels

- **label_possible** (warning): flags unlabeled parameters in functions with 2+ parameters
- **missing_labels** (warning): flags calls to same-module functions that omit defined labels

### Imports

- **unqualified_import** (warning): flags unqualified function/constant imports (e.g. `import mod.{func}`). Gleam convention is to use qualified access (`mod.func`). Constructor imports (`Some`, `None`, `Ok`, etc.) and type imports are not flagged.
- **duplicate_import** (warning): flags importing the same module more than once in a file

### Cross-Module

- **unused_exports** (warning): flags `pub` functions, constants, and types never referenced from another module. Test files count as consumers, `main` is excluded.

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
function_complexity = "warning"
module_complexity = "warning"
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

## Roadmap

- **Stateful rule interface**: change the check callbacks to a fold-like interface so rules can accumulate state across AST nodes, support multiple passes, and early termination. The current stateless `fn(Node) -> List(LintResult)` interface works for pattern-matching rules but limits what's possible. See [elm-review](https://package.elm-lang.org/packages/jfmengels/elm-review/latest/) for a well-designed reference architecture.
- **FFI safety lint**: detect use of private Gleam data API internals in JS FFI files (e.g. accessing tuple elements by index or matching on internal constructor representations).
- **Dynamic SQL detection**: flag string concatenation used to build SQL queries, which risks SQL injection.
- **Per-directory rule overrides**: apply different rule configs to different directories (e.g. permissive rules for `test/` where `let assert`, short names, and missing labels are idiomatic).
- **Abbreviation detection**: extend `short_variable_name` to flag common abbreviations (e.g. `req`, `ctx`, `cfg`) beyond single characters.

## Running Tests

```sh
gleam test
```

## License

MIT
