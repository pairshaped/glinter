# nolint Comment Annotations Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add `// nolint: rule1, rule2 -- reason` comment annotations for line-level and function-level warning suppression, with stale annotation detection.

**Architecture:** New `annotation.gleam` module parses source comments into suppression directives. Runner post-filters errors against these directives after rules execute. `byte_offset_to_line` is extracted from reporter into a shared utility so both reporter and runner can use it.

**Tech Stack:** Gleam, glance (AST parser for function spans)

---

## File Structure

- **Create:** `src/glinter/annotation.gleam` — parse `// nolint:` comments, determine scope
- **Create:** `src/glinter/source.gleam` — shared `byte_offset_to_line` utility
- **Create:** `test/glinter/annotation_test.gleam` — unit tests for annotation parsing
- **Modify:** `src/glinter/reporter.gleam` — import `byte_offset_to_line` from source.gleam instead of private fn
- **Modify:** `src/glinter/runner.gleam` — post-filter errors using annotations
- **Create:** `test/glinter/nolint_integration_test.gleam` — integration tests for suppression
- **Modify:** `README.md` — add "Suppressing warnings" section
- **Modify:** `LLM_USERS.md` — nolint examples already present (added during this session)

---

### Task 1: Extract byte_offset_to_line to shared module

**Files:**
- Create: `src/glinter/source.gleam`
- Modify: `src/glinter/reporter.gleam:18-37`

- [ ] **Step 1: Create `src/glinter/source.gleam` with the shared utility**

```gleam
import gleam/bit_array
import gleam/list
import gleam/string

/// Convert byte offset to line number (1-indexed)
pub fn byte_offset_to_line(source: String, offset: Int) -> Int {
  let source_bytes = <<source:utf8>>
  let size = bit_array.byte_size(source_bytes)
  let clamped = case offset <= size {
    True -> offset
    False -> size
  }
  case bit_array.slice(source_bytes, 0, clamped) {
    Ok(bytes) ->
      case bit_array.to_string(bytes) {
        Ok(s) ->
          s
          |> string.split("\n")
          |> list.length()
        Error(_) -> 1
      }
    Error(_) -> 1
  }
}
```

- [ ] **Step 2: Update `src/glinter/reporter.gleam` to use the shared utility**

Replace the private `byte_offset_to_line` function (lines 18-37) with an import. Add to the imports:

```gleam
import glinter/source
```

Remove the entire `fn byte_offset_to_line(source: String, offset: Int) -> Int { ... }` function (lines 18-37).

Replace all calls to `byte_offset_to_line(` with `source.byte_offset_to_line(` in reporter.gleam. There is one call site at line 47:

```gleam
let line = case list.find(sources, fn(s) { s.0 == r.file }) {
  Ok(#(_, source_text)) -> source.byte_offset_to_line(source_text, r.location.start)
  _ -> 0
}
```

Note: the local variable is renamed to `source_text` to avoid shadowing the `source` module import.

- [ ] **Step 3: Run all tests**

Run: `gleam test 2>&1`
Expected: All 257 tests pass. No behavior change.

- [ ] **Step 4: Commit**

```bash
git add src/glinter/source.gleam src/glinter/reporter.gleam
git commit -m "Extract byte_offset_to_line to shared source module

Move from reporter.gleam to source.gleam so both reporter and
runner can convert Span byte offsets to line numbers."
```

---

### Task 2: Implement annotation parser

**Files:**
- Create: `src/glinter/annotation.gleam`
- Create: `test/glinter/annotation_test.gleam`

- [ ] **Step 1: Write failing tests for annotation parsing**

Create `test/glinter/annotation_test.gleam`:

```gleam
import gleam/list
import glinter/annotation.{FunctionScope, LineScope, Stale}

pub fn parses_standalone_nolint_test() {
  let results = annotation.parse("// nolint: avoid_panic\npanic as \"x\"")
  let assert True = list.length(results) == 1
  let assert [a] = results
  let assert True = a.rules == ["avoid_panic"]
  let assert True = a.target_line == 2
  let assert True = a.scope == LineScope
}

pub fn parses_inline_nolint_test() {
  let results = annotation.parse("let _ = x // nolint: discarded_result")
  let assert True = list.length(results) == 1
  let assert [a] = results
  let assert True = a.rules == ["discarded_result"]
  let assert True = a.target_line == 1
  let assert True = a.scope == LineScope
}

pub fn parses_multiple_rules_test() {
  let results =
    annotation.parse(
      "// nolint: deep_nesting, function_complexity\nfn walk() { 1 }",
    )
  let assert True = list.length(results) == 1
  let assert [a] = results
  let assert True = a.rules == ["deep_nesting", "function_complexity"]
}

pub fn ignores_reason_after_dashes_test() {
  let results =
    annotation.parse(
      "// nolint: avoid_panic -- unreachable fallback\npanic as \"x\"",
    )
  let assert True = list.length(results) == 1
  let assert [a] = results
  let assert True = a.rules == ["avoid_panic"]
}

pub fn detects_function_scope_fn_test() {
  let results =
    annotation.parse(
      "// nolint: deep_nesting\nfn walk(x) { x }",
    )
  let assert True = list.length(results) == 1
  let assert [a] = results
  let assert True = a.scope == FunctionScope
  let assert True = a.target_line == 2
}

pub fn detects_function_scope_pub_fn_test() {
  let results =
    annotation.parse(
      "// nolint: deep_nesting\npub fn walk(x) { x }",
    )
  let assert True = list.length(results) == 1
  let assert [a] = results
  let assert True = a.scope == FunctionScope
  let assert True = a.target_line == 2
}

pub fn detects_line_scope_for_non_fn_test() {
  let results =
    annotation.parse(
      "// nolint: thrown_away_error\nError(_) -> Ok([])",
    )
  let assert True = list.length(results) == 1
  let assert [a] = results
  let assert True = a.scope == LineScope
  let assert True = a.target_line == 2
}

pub fn detects_stale_annotation_blank_line_test() {
  let results = annotation.parse("// nolint: avoid_panic\n\npanic")
  let assert True = list.length(results) == 1
  let assert [a] = results
  let assert True = a.scope == Stale
}

pub fn detects_stale_annotation_eof_test() {
  let results = annotation.parse("// nolint: avoid_panic")
  let assert True = list.length(results) == 1
  let assert [a] = results
  let assert True = a.scope == Stale
}

pub fn no_annotations_returns_empty_test() {
  let results = annotation.parse("pub fn ok() { 1 }")
  let assert True = results == []
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `gleam test 2>&1 | head -20`
Expected: Compile error — `annotation` module doesn't exist yet.

- [ ] **Step 3: Implement `src/glinter/annotation.gleam`**

```gleam
import gleam/list
import gleam/string

pub type Scope {
  LineScope
  FunctionScope
  Stale
}

pub type Annotation {
  Annotation(rules: List(String), target_line: Int, scope: Scope)
}

/// Parse source text for // nolint: comments and return annotations.
pub fn parse(source: String) -> List(Annotation) {
  let lines = string.split(source, "\n")
  parse_lines(lines, 1, [])
}

fn parse_lines(
  lines: List(String),
  line_num: Int,
  acc: List(Annotation),
) -> List(Annotation) {
  case lines {
    [] -> list.reverse(acc)
    [line, ..rest] -> {
      case extract_nolint(line) {
        Ok(rules) -> {
          let #(scope, target_line) = determine_scope(line, rest, line_num)
          let annotation = Annotation(rules: rules, target_line: target_line, scope: scope)
          parse_lines(rest, line_num + 1, [annotation, ..acc])
        }
        Error(_) -> parse_lines(rest, line_num + 1, acc)
      }
    }
  }
}

/// Extract rule names from a line containing // nolint:
/// Returns Error(Nil) if the line doesn't contain a nolint directive.
fn extract_nolint(line: String) -> Result(List(String), Nil) {
  case string.split(line, "// nolint:") {
    [_, after_prefix] -> {
      // Strip reason (everything after --)
      let rules_part = case string.split(after_prefix, "--") {
        [before_reason, ..] -> before_reason
        _ -> after_prefix
      }
      let rules =
        rules_part
        |> string.split(",")
        |> list.map(string.trim)
        |> list.filter(fn(s) { s != "" })
      case rules {
        [] -> Error(Nil)
        _ -> Ok(rules)
      }
    }
    _ -> Error(Nil)
  }
}

/// Determine scope based on whether the line is inline and what follows it.
fn determine_scope(
  current_line: String,
  remaining_lines: List(String),
  current_line_num: Int,
) -> #(Scope, Int) {
  // Check if this is an inline annotation (code before // nolint:)
  let before_nolint = case string.split(current_line, "// nolint:") {
    [prefix, ..] -> string.trim(prefix)
    _ -> ""
  }
  case before_nolint {
    // Standalone comment line — check what follows
    "" -> {
      case remaining_lines {
        [] -> #(Stale, current_line_num)
        [next_line, ..] -> {
          let trimmed = string.trim(next_line)
          case trimmed {
            "" -> #(Stale, current_line_num)
            _ ->
              case
                string.starts_with(trimmed, "fn ")
                || string.starts_with(trimmed, "pub fn ")
              {
                True -> #(FunctionScope, current_line_num + 1)
                False ->
                  case string.starts_with(trimmed, "//") {
                    True -> #(Stale, current_line_num)
                    False -> #(LineScope, current_line_num + 1)
                  }
              }
          }
        }
      }
    }
    // Inline — suppress the current line
    _ -> #(LineScope, current_line_num)
  }
}
```

- [ ] **Step 4: Run all tests**

Run: `gleam test 2>&1`
Expected: All tests pass including the 10 new annotation tests.

- [ ] **Step 5: Commit**

```bash
git add src/glinter/annotation.gleam test/glinter/annotation_test.gleam
git commit -m "Add annotation parser for // nolint: comments

Parses source text for nolint directives. Determines scope:
line-level (next line or inline), function-level (next line
is fn/pub fn), or stale (followed by blank/comment/EOF)."
```

---

### Task 3: Integrate annotation filtering into runner

**Files:**
- Modify: `src/glinter/runner.gleam`
- Create: `test/glinter/nolint_integration_test.gleam`

- [ ] **Step 1: Write failing integration tests**

Create `test/glinter/nolint_integration_test.gleam`:

```gleam
import glance
import gleam/dict
import gleam/list
import glinter/config
import glinter/rule
import glinter/runner

fn make_config() -> config.Config {
  config.Config(
    rules: dict.new(),
    ignore: dict.new(),
    include: ["src/"],
    exclude: [],
    stats: False,
    warnings_as_errors: False,
  )
}

fn run_with_source(
  source: String,
  rules: List(rule.Rule),
) -> List(rule.LintResult) {
  let assert Ok(module) = glance.module(source)
  let files = [#("test.gleam", source, module)]
  runner.run(rules: rules, files: files, config: make_config())
}

pub fn line_level_suppression_test() {
  let source =
    "pub fn bad() {
  // nolint: avoid_panic
  panic as \"ok\"
}"
  let results = run_with_source(source, [rule_for("avoid_panic")])
  let assert True = results == []
}

pub fn inline_suppression_test() {
  let source = "pub fn bad() { panic as \"ok\" } // nolint: avoid_panic"
  // Note: inline suppression targets the same line
  // The panic is inside a function on line 1, but the nolint is also on line 1
  // This tests that inline annotation works
  let results = run_with_source(source, [rule_for("avoid_panic")])
  let assert True = results == []
}

pub fn function_level_suppression_test() {
  let source =
    "// nolint: avoid_panic
pub fn fallback() {
  panic as \"unreachable\"
}"
  let results = run_with_source(source, [rule_for("avoid_panic")])
  let assert True = results == []
}

pub fn unrelated_errors_not_suppressed_test() {
  let source =
    "// nolint: deep_nesting
pub fn bad() {
  panic as \"oh no\"
}"
  // nolint is for deep_nesting, not avoid_panic
  let results = run_with_source(source, [rule_for("avoid_panic")])
  let assert True = list.length(results) == 1
}

pub fn stale_annotation_produces_warning_test() {
  let source =
    "// nolint: avoid_panic

pub fn good() { 1 }"
  let results = run_with_source(source, [rule_for("avoid_panic")])
  let nolint_warnings =
    results |> list.filter(fn(r) { r.rule == "nolint_unused" })
  let assert True = list.length(nolint_warnings) == 1
}

pub fn unused_annotation_produces_warning_test() {
  // The annotation matches no actual error (function has no panic)
  let source =
    "// nolint: avoid_panic
pub fn good() { 1 }"
  let results = run_with_source(source, [rule_for("avoid_panic")])
  let nolint_warnings =
    results |> list.filter(fn(r) { r.rule == "nolint_unused" })
  let assert True = list.length(nolint_warnings) == 1
}

/// Helper: get the avoid_panic rule (it's always available as a built-in)
fn rule_for(name: String) -> rule.Rule {
  // We need to import the actual rules. Use avoid_panic for testing.
  case name {
    "avoid_panic" -> {
      // Import dynamically isn't possible in Gleam.
      // We'll use the actual rule module.
      panic as "helper not implemented yet"
    }
    _ -> panic as "unknown rule"
  }
}
```

Actually, this test helper approach is problematic. Let me redesign — we need to import actual rule modules.

Replace the test file with:

```gleam
import glance
import gleam/dict
import gleam/list
import glinter/config
import glinter/rule
import glinter/rules/avoid_panic
import glinter/runner

fn make_config() -> config.Config {
  config.Config(
    rules: dict.new(),
    ignore: dict.new(),
    include: ["src/"],
    exclude: [],
    stats: False,
    warnings_as_errors: False,
  )
}

fn run_with_source(
  source: String,
  rules: List(rule.Rule),
) -> List(rule.LintResult) {
  let assert Ok(module) = glance.module(source)
  let files = [#("test.gleam", source, module)]
  runner.run(rules: rules, files: files, config: make_config())
}

pub fn line_level_suppression_test() {
  let source =
    "pub fn bad() {\n  // nolint: avoid_panic\n  panic as \"ok\"\n}"
  let results = run_with_source(source, [avoid_panic.rule()])
  let panic_errors =
    results |> list.filter(fn(r) { r.rule == "avoid_panic" })
  let assert True = panic_errors == []
}

pub fn function_level_suppression_test() {
  let source =
    "// nolint: avoid_panic\npub fn fallback() {\n  panic as \"unreachable\"\n}"
  let results = run_with_source(source, [avoid_panic.rule()])
  let panic_errors =
    results |> list.filter(fn(r) { r.rule == "avoid_panic" })
  let assert True = panic_errors == []
}

pub fn unrelated_rule_not_suppressed_test() {
  let source =
    "// nolint: deep_nesting\npub fn bad() {\n  panic as \"oh no\"\n}"
  let results = run_with_source(source, [avoid_panic.rule()])
  let panic_errors =
    results |> list.filter(fn(r) { r.rule == "avoid_panic" })
  let assert True = list.length(panic_errors) == 1
}

pub fn stale_annotation_produces_warning_test() {
  let source = "// nolint: avoid_panic\n\npub fn good() { 1 }"
  let results = run_with_source(source, [avoid_panic.rule()])
  let nolint_warnings =
    results |> list.filter(fn(r) { r.rule == "nolint_unused" })
  let assert True = list.length(nolint_warnings) == 1
}

pub fn unused_annotation_produces_warning_test() {
  let source = "// nolint: avoid_panic\npub fn good() { 1 }"
  let results = run_with_source(source, [avoid_panic.rule()])
  let nolint_warnings =
    results |> list.filter(fn(r) { r.rule == "nolint_unused" })
  let assert True = list.length(nolint_warnings) == 1
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `gleam test 2>&1 | head -20`
Expected: Tests fail because runner doesn't filter annotations yet.

- [ ] **Step 3: Implement annotation filtering in `src/glinter/runner.gleam`**

Add imports at the top of runner.gleam:

```gleam
import glinter/annotation
import glinter/source
```

In `run_module_rules`, modify the `pmap` callback to post-filter results. After collecting all `LintResult`s for a file, apply annotation filtering. Replace the `pmap` callback body (lines 29-51) with:

```gleam
    func: fn(file) {
      let #(display_path, source_text, module) = file
      let active_rules =
        rules
        |> list.filter(fn(r) {
          !ignore.is_rule_ignored(display_path, rule.name(r), config.ignore)
        })

      let results =
        active_rules
        |> list.flat_map(fn(r) {
          rule.run_on_module(rule: r, module: module, source: source_text)
          |> list.map(fn(err) {
            LintResult(
              rule: rule.name(r),
              severity: rule.default_severity(r),
              file: display_path,
              location: rule.error_location(err),
              message: rule.error_message(err),
              details: rule.error_details(err),
            )
          })
        })

      apply_annotations(results, source_text, module, display_path)
    },
```

Add the `apply_annotations` function at the bottom of runner.gleam (before the `pmap` external):

```gleam
fn apply_annotations(
  results: List(LintResult),
  source_text: String,
  module: glance.Module,
  file: String,
) -> List(LintResult) {
  let annotations = annotation.parse(source_text)

  // Build function line ranges from the AST for function-scope annotations
  let function_ranges =
    module.functions
    |> list.map(fn(func_def) {
      let function = func_def.definition
      let start_line = source.byte_offset_to_line(source_text, function.location.start)
      let end_line = source.byte_offset_to_line(source_text, function.location.end)
      #(start_line, end_line)
    })

  // Filter results and track which annotations were used
  let #(filtered_results, used_annotations) =
    list.fold(results, #([], []), fn(acc, result) {
      let #(kept, used) = acc
      let result_line =
        source.byte_offset_to_line(source_text, result.location.start)
      case find_matching_annotation(result, result_line, annotations, function_ranges) {
        Ok(matched_annotation) -> #(kept, [matched_annotation, ..used])
        Error(_) -> #([result, ..kept], used)
      }
    })

  // Generate warnings for stale or unused annotations
  let stale_warnings =
    annotations
    |> list.filter(fn(a) { a.scope == annotation.Stale })
    |> list.map(fn(a) {
      LintResult(
        rule: "nolint_unused",
        severity: rule.Warning,
        file: file,
        location: glance.Span(start: 0, end: 0),
        message: "Stale nolint annotation: not followed by code",
        details: "This // nolint: comment is followed by a blank line or end of file. Move it directly above the code it should suppress.",
      )
    })

  let unused_warnings =
    annotations
    |> list.filter(fn(a) {
      a.scope != annotation.Stale
      && !list.contains(used_annotations, a)
    })
    |> list.map(fn(a) {
      let rules_str =
        a.rules
        |> list.map(fn(r) { r })
        |> string.join(", ")
      LintResult(
        rule: "nolint_unused",
        severity: rule.Warning,
        file: file,
        location: glance.Span(start: 0, end: 0),
        message: "Unused nolint annotation: no " <> rules_str <> " warnings were suppressed",
        details: "This // nolint: comment didn't suppress any warnings. Remove it if the code has been fixed, or check the rule names for typos.",
      )
    })

  list.flatten([list.reverse(filtered_results), stale_warnings, unused_warnings])
}

fn find_matching_annotation(
  result: LintResult,
  result_line: Int,
  annotations: List(annotation.Annotation),
  function_ranges: List(#(Int, Int)),
) -> Result(annotation.Annotation, Nil) {
  list.find(annotations, fn(a) {
    let rule_matches = list.contains(a.rules, result.rule)
    case rule_matches {
      False -> False
      True ->
        case a.scope {
          annotation.LineScope -> result_line == a.target_line
          annotation.FunctionScope ->
            // Find the function range that starts at target_line
            case
              list.find(function_ranges, fn(range) {
                range.0 == a.target_line
              })
            {
              Ok(#(start, end)) ->
                result_line >= start && result_line <= end
              Error(_) -> False
            }
          annotation.Stale -> False
        }
    }
  })
}
```

Also add `import gleam/string` to the imports in runner.gleam.

- [ ] **Step 4: Run all tests**

Run: `gleam test 2>&1`
Expected: All tests pass including the 5 new integration tests.

- [ ] **Step 5: Commit**

```bash
git add src/glinter/runner.gleam test/glinter/nolint_integration_test.gleam
git commit -m "Integrate nolint annotation filtering into runner

Post-filter lint results against parsed annotations. Line-scope
annotations suppress errors on the target line. Function-scope
annotations suppress errors within the function's span. Stale
and unused annotations produce nolint_unused warnings."
```

---

### Task 4: Update README documentation

**Files:**
- Modify: `README.md`

- [ ] **Step 1: Add "Suppressing Warnings" section to README**

Insert the following section after the "Ignoring Rules Per File" section (after line 186) and before "## Output Formats" (line 188):

```markdown
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
```

- [ ] **Step 2: Run all tests to ensure nothing broke**

Run: `gleam test 2>&1`
Expected: All tests pass.

- [ ] **Step 3: Commit**

```bash
git add README.md
git commit -m "Document nolint comment annotations in README

Add Suppressing Warnings section covering line-level,
function-level, and stale annotation detection."
```

---

### Task 5: Version bump

**Files:**
- Modify: `gleam.toml`

- [ ] **Step 1: Bump version to 2.13.0**

In `gleam.toml`, change:

```toml
version = "2.12.2"
```

to:

```toml
version = "2.13.0"
```

- [ ] **Step 2: Run all tests one final time**

Run: `gleam test 2>&1`
Expected: All tests pass.

- [ ] **Step 3: Commit**

```bash
git add gleam.toml
git commit -m "Bump version to 2.13.0"
```
