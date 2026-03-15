import glance
import gleam/list
import gleam/string
import glinter/rule.{type Rule, LintResult, Rule, Warning}

pub fn rule() -> Rule {
  Rule(name: "unqualified_import", default_severity: Warning, check: check)
}

fn check(data: rule.ModuleData, _source: String) -> List(rule.LintResult) {
  data.module.imports
  |> list.flat_map(fn(def) {
    let glance.Definition(_, import_) = def
    import_.unqualified_values
    |> list.filter_map(fn(uq) {
      // Allow PascalCase constructors (Some, None, Ok, Error, etc.)
      // Only flag snake_case functions and constants
      case is_lowercase_start(uq.name) {
        True ->
          Ok(LintResult(
            rule: "unqualified_import",
            severity: Warning,
            file: "",
            location: import_.location,
            message: "Function '"
              <> uq.name
              <> "' is imported unqualified from '"
              <> import_.module
              <> "', use qualified access instead",
          ))
        False -> Error(Nil)
      }
    })
  })
}

fn is_lowercase_start(name: String) -> Bool {
  case string.first(name) {
    Ok(c) -> c == string.lowercase(c)
    Error(_) -> False
  }
}
