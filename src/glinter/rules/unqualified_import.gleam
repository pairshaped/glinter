import glance
import gleam/list
import gleam/string
import glinter/rule.{type V2Rule, RuleResult, V2Rule, Warning}

pub fn rule() -> V2Rule {
  V2Rule(
    name: "unqualified_import",
    default_severity: Warning,
    needs_collect: False,
    check: check,
  )
}

fn check(data: rule.ModuleData, _source: String) -> List(rule.RuleResult) {
  data.module.imports
  |> list.flat_map(fn(def) {
    let glance.Definition(_, import_) = def
    import_.unqualified_values
    |> list.filter_map(fn(uq) {
      // Allow PascalCase constructors (Some, None, Ok, Error, etc.)
      // Only flag snake_case functions and constants
      case is_lowercase_start(uq.name) {
        True ->
          Ok(RuleResult(
            rule: "unqualified_import",
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
