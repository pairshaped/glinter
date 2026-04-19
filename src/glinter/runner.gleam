import glance
import gleam/dict
import gleam/list
import gleam/string
import glinter/annotation
import glinter/config
import glinter/ignore
import glinter/rule.{type LintResult, LintResult}
import glinter/source

/// Run all rules against all files. Module rules run in parallel per file.
/// Project rules run module visitors sequentially, fold contexts, then final eval.
pub fn run(
  rules rules: List(rule.Rule),
  files files: List(#(String, String, glance.Module)),
  config config: config.Config,
) -> List(LintResult) {
  let #(module_rules, project_rules) =
    list.partition(rules, fn(r) { !rule.is_project_rule(r) })

  let module_results = run_module_rules(module_rules, files, config)
  let project_results = run_project_rules(project_rules, files, config)

  list.append(module_results, project_results)
}

fn run_module_rules(
  rules rules: List(rule.Rule),
  files files: List(#(String, String, glance.Module)),
  config config: config.Config,
) -> List(LintResult) {
  pmap(
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

      apply_annotations(
        results,
        source_text,
        module,
        display_path,
        config.ignore,
      )
    },
    items: files,
  )
  |> list.flatten()
}

fn run_project_rules(
  rules rules: List(rule.Rule),
  files files: List(#(String, String, glance.Module)),
  config config: config.Config,
) -> List(LintResult) {
  let file_tuples =
    files
    |> list.map(fn(f) {
      let #(_display_path, source_text, module) = f
      #(module, source_text)
    })

  rules
  |> list.flat_map(fn(r) {
    let rule_name = rule.name(r)
    let severity = rule.default_severity(r)

    rule.run_on_project(rule: r, files: file_tuples)
    |> list.filter_map(fn(err) {
      // Project rule errors don't have a file path in the error itself.
      // Use empty string as default -- project rules that need file paths
      // should encode them in the error message or details.
      let file = ""
      case ignore.is_rule_ignored(file, rule_name, config.ignore) {
        True -> Error(Nil)
        False ->
          Ok(LintResult(
            rule: rule_name,
            severity: severity,
            file: file,
            location: rule.error_location(err),
            message: rule.error_message(err),
            details: rule.error_details(err),
          ))
      }
    })
  })
}

/// Filter results by nolint annotations without emitting unused warnings.
/// Used for project-rule results that are collected outside the module rules pass.
pub fn filter_annotations(
  results: List(LintResult),
  source_text: String,
  module: glance.Module,
) -> List(LintResult) {
  let annotations = annotation.parse(source_text)
  let function_ranges =
    module.functions
    |> list.map(fn(func_def) {
      let span = func_def.definition.location
      let start_line = source.byte_offset_to_line(source_text, span.start)
      let end_line = source.byte_offset_to_line(source_text, span.end)
      #(start_line, end_line)
    })

  results
  |> list.filter(fn(result) {
    let error_line =
      source.byte_offset_to_line(source_text, result.location.start)
    case
      find_matching_annotation(
        result,
        error_line,
        annotations,
        function_ranges,
        0,
      )
    {
      Ok(_) -> False
      Error(_) -> True
    }
  })
}

/// Apply nolint annotations to filter results and emit warnings for unused annotations.
fn apply_annotations(
  results: List(LintResult),
  source_text: String,
  module: glance.Module,
  file: String,
  ignore_config: dict.Dict(String, List(String)),
) -> List(LintResult) {
  let annotations = annotation.parse(source_text)

  // Build function line ranges: list of #(start_line, end_line)
  let function_ranges =
    module.functions
    |> list.map(fn(func_def) {
      let span = func_def.definition.location
      let start_line = source.byte_offset_to_line(source_text, span.start)
      let end_line = source.byte_offset_to_line(source_text, span.end)
      #(start_line, end_line)
    })

  // For each result, check if it's suppressed by an annotation.
  // Track which annotations actually suppress something.
  let #(kept_results, used_annotation_indices) =
    list.fold(results, #([], []), fn(acc, result) {
      let #(kept, used_indices) = acc
      let error_line =
        source.byte_offset_to_line(source_text, result.location.start)
      case
        find_matching_annotation(
          result,
          error_line,
          annotations,
          function_ranges,
          0,
        )
      {
        Ok(idx) -> #(kept, [idx, ..used_indices])
        Error(Nil) -> #([result, ..kept], used_indices)
      }
    })

  let kept_results = list.reverse(kept_results)

  // Emit nolint_unused warnings (unless nolint_unused is ignored for this file)
  let nolint_ignored =
    ignore.is_rule_ignored(file, "nolint_unused", ignore_config)
  let unused_warnings = case nolint_ignored {
    True -> []
    False ->
      annotations
      |> list.index_map(fn(ann, idx) {
        // Inline annotations are reported separately as nolint_inline; don't
        // also flag them as unused (the underlying error already fires too).
        case ann.inline {
          True -> []
          False ->
            case ann.scope {
              annotation.Stale -> {
                let offset =
                  source.line_to_byte_offset(source_text, ann.comment_line)
                [
                  LintResult(
                    rule: "nolint_unused",
                    severity: rule.Warning,
                    file: file,
                    location: glance.Span(start: offset, end: offset),
                    message: "Stale nolint annotation is not followed by code",
                    details: "This // nolint: comment is followed by a blank line or end of file. Move it directly above the code it should suppress.",
                  ),
                ]
              }
              _ ->
                case list.contains(used_annotation_indices, idx) {
                  True -> []
                  False -> {
                    let offset =
                      source.line_to_byte_offset(source_text, ann.comment_line)
                    let rules_str = string.join(ann.rules, ", ")
                    [
                      LintResult(
                        rule: "nolint_unused",
                        severity: rule.Warning,
                        file: file,
                        location: glance.Span(start: offset, end: offset),
                        message: "Unused nolint annotation: no "
                          <> rules_str
                          <> " warnings were suppressed",
                        details: "This // nolint: comment didn't suppress any warnings. Remove it if the code has been fixed, or check the rule names for typos.",
                      ),
                    ]
                  }
                }
            }
        }
      })
      |> list.flatten()
  }

  // Emit nolint_inline warnings for trailing inline nolints. These are
  // disallowed because `gleam format` may move them off the line when wrapping,
  // silently breaking the suppression. Suppression is also disabled for these
  // (see find_matching_annotation), so the underlying error still fires.
  let inline_ignored =
    ignore.is_rule_ignored(file, "nolint_inline", ignore_config)
  let inline_warnings = case inline_ignored {
    True -> []
    False ->
      annotations
      |> list.filter_map(fn(ann) {
        case ann.inline {
          False -> Error(Nil)
          True -> {
            let offset =
              source.line_to_byte_offset(source_text, ann.comment_line)
            Ok(LintResult(
              rule: "nolint_inline",
              severity: rule.Warning,
              file: file,
              location: glance.Span(start: offset, end: offset),
              message: "Trailing inline nolint is disallowed: move it to its own line above the target",
              details: "// nolint comments must precede the line they suppress, e.g.\n    // nolint: avoid_panic\n    panic as \"x\"\nTrailing inline placement (`code // nolint:`) is fragile because `gleam format` may move the comment off the line when wrapping, silently breaking the suppression.",
            ))
          }
        }
      })
  }

  list.append(kept_results, list.append(unused_warnings, inline_warnings))
}

/// Find the index of an annotation that suppresses the given result.
/// Returns Ok(index) if found, Error(Nil) if not suppressed.
fn find_matching_annotation(
  result: LintResult,
  error_line: Int,
  annotations: List(annotation.Annotation),
  function_ranges: List(#(Int, Int)),
  idx: Int,
) -> Result(Int, Nil) {
  case annotations {
    [] -> Error(Nil)
    [ann, ..rest] -> {
      // Inline trailing nolints are disallowed (they break under gleam format).
      // Skip them entirely so the underlying error fires; the runner emits a
      // separate `nolint_inline` warning.
      let rule_matches = !ann.inline && list.contains(ann.rules, result.rule)
      let line_matches = case ann.scope {
        annotation.LineScope -> ann.target_line == error_line
        annotation.FunctionScope ->
          // Find the function that starts at target_line and check if error is within it
          is_in_function_scope(error_line, ann.target_line, function_ranges)
        annotation.Stale -> False
      }
      case rule_matches && line_matches {
        True -> Ok(idx)
        False ->
          find_matching_annotation(
            result,
            error_line,
            rest,
            function_ranges,
            idx + 1,
          )
      }
    }
  }
}

/// Check if error_line falls within the function that starts at fn_start_line.
fn is_in_function_scope(
  error_line: Int,
  fn_start_line: Int,
  function_ranges: List(#(Int, Int)),
) -> Bool {
  list.any(function_ranges, fn(range) {
    let #(start, end) = range
    start == fn_start_line && error_line >= start && error_line <= end
  })
}

@external(erlang, "glinter_ffi", "pmap")
fn pmap(func func: fn(a) -> b, items items: List(a)) -> List(b)
