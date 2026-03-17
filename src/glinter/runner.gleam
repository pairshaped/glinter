import glance
import gleam/list
import glinter/config
import glinter/ignore
import glinter/rule.{type LintResult, LintResult}

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
      let #(display_path, source, module) = file
      let active_rules =
        rules
        |> list.filter(fn(r) {
          !ignore.is_rule_ignored(display_path, rule.name(r), config.ignore)
        })

      active_rules
      |> list.flat_map(fn(r) {
        rule.run_on_module(rule: r, module: module, source: source)
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
      let #(_display_path, source, module) = f
      #(module, source)
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

@external(erlang, "glinter_ffi", "pmap")
fn pmap(func func: fn(a) -> b, items items: List(a)) -> List(b)
