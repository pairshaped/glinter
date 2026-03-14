# glinter

A linter for the [Gleam](https://gleam.run) programming language. It parses Gleam source files into ASTs using [glance](https://github.com/gleam-community/glance) and checks them against a configurable set of rules.

## Installation

```sh
git clone https://github.com/pairshaped/glinter.git
cd glinter
gleam build
```

## Usage

```sh
# Lint the src/ directory (default)
gleam run -m glinter

# Lint specific files or directories
gleam run -m glinter src/myapp/ test/

# JSON output
gleam run -m glinter --format json

# Custom config file
gleam run -m glinter --config my_config.toml

# Lint a different project (resolves config and paths relative to project dir)
gleam run -m glinter --project /path/to/my/project server/src shared/src
```

The exit code is `1` if any issues are found, `0` otherwise.

## Rules

### Code Quality

| Rule | Default | Description |
|------|---------|-------------|
| `avoid_panic` | error | Flags uses of `panic` |
| `avoid_todo` | error | Flags uses of `todo` |
| `echo` | warning | Flags uses of `echo` (debug output) |
| `assert_ok_pattern` | warning | Flags `let assert` assignments |
| `unwrap_used` | warning | Flags `result.unwrap`, `option.unwrap`, and lazy variants |

### Style

| Rule | Default | Description |
|------|---------|-------------|
| `discarded_result` | warning | Flags `let _ = expr` (discarded results) |
| `short_variable_name` | warning | Flags single-character variable names in let bindings |
| `unnecessary_variable` | warning | Flags `let x = expr; x` — variable assigned then immediately returned |
| `redundant_case` | warning | Flags `case` expressions with a single branch and no guard |
| `prefer_guard_clause` | warning | Flags `case bool { True -> ... False -> ... }` patterns that could use `bool.guard` |

### Complexity

| Rule | Default | Description |
|------|---------|-------------|
| `deep_nesting` | warning | Flags nesting deeper than 5 levels |
| `function_complexity` | warning | Flags functions with more than 10 branching nodes |
| `module_complexity` | warning | Flags modules with more than 50 total branching nodes |

### Labels

| Rule | Default | Description |
|------|---------|-------------|
| `label_possible` | warning | Flags unlabeled parameters in functions with 2+ parameters |
| `missing_labels` | warning | Flags calls to same-module functions that omit defined labels |

### Cross-Module

| Rule | Default | Description |
|------|---------|-------------|
| `unused_exports` | warning | Flags `pub` functions, constants, and types never referenced from another module. Uses cross-module import graph analysis — test files count as consumers, `main` is excluded. |

## Configuration

Create a `glinter.toml` file in your project root:

```toml
[rules]
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
[ignore]
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
