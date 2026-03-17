import gleam/list
import gleam/string
import glinter/rule.{type V2Rule, RuleResult, V2Rule, Warning}

pub fn rule() -> V2Rule {
  V2Rule(
    name: "trailing_underscore",
    default_severity: Warning,
    needs_collect: False,
    check: check,
  )
}

fn check(data: rule.ModuleData, _source: String) -> List(rule.RuleResult) {
  data.module.functions
  |> list.filter_map(fn(def) {
    let func = def.definition
    case string.ends_with(func.name, "_") {
      True ->
        [
          RuleResult(
            rule: "trailing_underscore",
            location: func.location,
            message: "Function '"
              <> func.name
              <> "' has a trailing underscore — remove it",
          ),
        ]
        |> Ok
      False -> Error(Nil)
    }
  })
  |> list.flatten
}
