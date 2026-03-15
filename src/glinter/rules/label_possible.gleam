import glance
import gleam/list
import gleam/option.{None}
import glinter/rule.{type Rule, LintResult, Rule, Warning}

pub fn rule() -> Rule {
  Rule(name: "label_possible", default_severity: Warning, check: check)
}

fn check(data: rule.ModuleData, _source: String) -> List(rule.LintResult) {
  data.module.functions
  |> list.flat_map(fn(def) { check_function(def.definition) })
}

fn check_function(func: glance.Function) -> List(rule.LintResult) {
  let params = func.parameters
  case list.length(params) >= 2 {
    False -> []
    True ->
      params
      |> list.filter(fn(param) { param.label == None })
      |> list.map(fn(param) {
        let name = case param.name {
          glance.Named(n) -> n
          glance.Discarded(n) -> "_" <> n
        }
        LintResult(
          rule: "label_possible",
          severity: Warning,
          file: "",
          location: func.location,
          message: "Parameter '"
            <> name
            <> "' could benefit from a label for clarity at call sites",
        )
      })
  }
}
