import glance
import gleam/int
import gleam/list
import glinter/analysis
import glinter/rule.{type Rule, LintResult, Rule, Warning}

const threshold = 10

pub fn rule() -> Rule {
  Rule(name: "function_complexity", default_severity: Warning, needs_collect: False, check: check)
}

fn check(data: rule.ModuleData, _source: String) -> List(rule.LintResult) {
  data.module.functions
  |> list.flat_map(fn(def) { check_function(def.definition) })
}

fn check_function(func: glance.Function) -> List(rule.LintResult) {
  let count = analysis.count_branches(func.body)
  case count > threshold {
    True -> [
      LintResult(
        rule: "function_complexity",
        severity: Warning,
        file: "",
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
