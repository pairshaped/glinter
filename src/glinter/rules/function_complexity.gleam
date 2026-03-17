import glance
import gleam/int
import gleam/list
import glinter/analysis
import glinter/rule.{type V2Rule, Off, RuleResult, V2Rule}

const threshold = 10

pub fn rule() -> V2Rule {
  V2Rule(
    name: "function_complexity",
    default_severity: Off,
    needs_collect: False,
    check: check,
  )
}

fn check(data: rule.ModuleData, _source: String) -> List(rule.RuleResult) {
  data.module.functions
  |> list.flat_map(fn(def) { check_function(def.definition) })
}

fn check_function(func: glance.Function) -> List(rule.RuleResult) {
  let count = analysis.count_branches(func.body)
  case count > threshold {
    True -> [
      RuleResult(
        rule: "function_complexity",
        location: func.location,
        message: "Function '"
          <> func.name
          <> "' has a complexity of "
          <> int.to_string(count)
          <> " — consider splitting into smaller functions",
      ),
    ]
    False -> []
  }
}
