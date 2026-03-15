import glance
import gleam/int
import gleam/list
import glinter/analysis
import glinter/rule.{type Rule, LintResult, Rule, Warning}

const threshold = 50

pub fn rule() -> Rule {
  Rule(name: "module_complexity", default_severity: Warning, needs_collect: False, check: check)
}

fn check(data: rule.ModuleData, _source: String) -> List(rule.LintResult) {
  let count =
    data.module.functions
    |> list.fold(0, fn(acc, def) {
      acc + analysis.count_branches(def.definition.body)
    })
  case count > threshold {
    True -> [
      LintResult(
        rule: "module_complexity",
        severity: Warning,
        file: "",
        location: glance.Span(0, 0),
        message: "Module has a complexity of "
          <> int.to_string(count)
          <> " — consider splitting into smaller modules",
      ),
    ]
    False -> []
  }
}
