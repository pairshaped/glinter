import glance
import gleam/list
import glinter/rule.{type Rule, LintResult, Rule, Warning}

pub fn rule() -> Rule {
  Rule(name: "duplicate_import", default_severity: Warning, needs_collect: False, check: check)
}

fn check(data: rule.ModuleData, _source: String) -> List(rule.LintResult) {
  data.module.imports
  |> list.fold(#([], []), fn(acc, def) {
    let #(seen, results) = acc
    let glance.Definition(_, import_) = def
    case list.contains(seen, import_.module) {
      True -> #(seen, [
        LintResult(
          rule: "duplicate_import",
          severity: Warning,
          file: "",
          location: import_.location,
          message: "Module '"
            <> import_.module
            <> "' is imported more than once",
        ),
        ..results
      ])
      False -> #([import_.module, ..seen], results)
    }
  })
  |> fn(acc) { list.reverse(acc.1) }
}
