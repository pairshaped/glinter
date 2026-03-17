import glance
import gleam/list
import gleam/option.{None}
import glinter/rule.{type V2Rule, RuleResult, V2Rule, Warning}

pub fn rule() -> V2Rule {
  V2Rule(
    name: "label_possible",
    default_severity: Warning,
    needs_collect: False,
    check: check,
  )
}

fn check(data: rule.ModuleData, _source: String) -> List(rule.RuleResult) {
  data.module.functions
  |> list.flat_map(fn(def) { check_function(def.definition) })
}

fn check_function(func: glance.Function) -> List(rule.RuleResult) {
  let params = func.parameters
  // Skip functions with fewer than 2 params, or any unlabelled discard param
  // (you can't fully label a function that has an unlabelled discard)
  let has_unlabelled_discard =
    list.any(params, fn(param) {
      param.label == None
      && case param.name {
        glance.Discarded(_) -> True
        glance.Named(_) -> False
      }
    })
  case list.length(params) >= 2 && !has_unlabelled_discard {
    False -> []
    True ->
      params
      |> list.filter(fn(param) { param.label == None })
      |> list.map(fn(param) {
        let assert glance.Named(name) = param.name
        RuleResult(
          rule: "label_possible",
          location: func.location,
          message: "Parameter '"
            <> name
            <> "' could benefit from a label for clarity at call sites",
        )
      })
  }
}
