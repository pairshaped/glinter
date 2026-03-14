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
gleam run -m glinter --project /path/to/my/project server/src shared/src
```

The exit code is `1` if any issues are found, `0` otherwise.

## Rules

### Code Quality

- **avoid_panic** (error): flags uses of `panic`
- **avoid_todo** (error): flags uses of `todo`
- **echo** (warning): flags uses of `echo` (debug output)
- **assert_ok_pattern** (warning): flags `let assert` assignments
- **unwrap_used** (warning): flags `result.unwrap`, `option.unwrap`, and lazy variants

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

### Cross-Module

- **unused_exports** (warning): flags `pub` functions, constants, and types never referenced from another module. Test files count as consumers, `main` is excluded.

## Configuration

Configuration lives in your project's `gleam.toml` under the `[tools.glinter]` key:

```toml
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
```

Each rule can be set to `"error"`, `"warning"`, or `"off"`.

### Ignoring Rules Per File

Suppress specific rules for files where they don't make sense:

```toml
[tools.glinter.ignore]
"src/my_complex_module.gleam" = ["deep_nesting", "function_complexity"]
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

Returns a JSON array of issues with file path, line, column, rule, severity, and message.

## Running Tests

```sh
gleam test
```

## License

MIT
