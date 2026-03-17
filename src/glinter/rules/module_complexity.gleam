import glance
import gleam/int
import glinter/analysis
import glinter/rule

const threshold = 100

type Context {
  Context(total_branches: Int)
}

pub fn rule() -> rule.Rule {
  rule.new_with_context(
    name: "module_complexity",
    initial: Context(total_branches: 0),
  )
  |> rule.with_default_severity(severity: rule.Off)
  |> rule.with_function_visitor(visitor: count_function)
  |> rule.with_final_evaluation(evaluator: evaluate)
  |> rule.to_module_rule()
}

fn count_function(
  function: glance.Function,
  _span: glance.Span,
  context: Context,
) -> #(List(rule.RuleError), Context) {
  let count = analysis.count_branches(function.body)
  #([], Context(total_branches: context.total_branches + count))
}

fn evaluate(context: Context) -> List(rule.RuleError) {
  case context.total_branches > threshold {
    True -> [
      rule.error(
        message: "Module has a complexity of "
          <> int.to_string(context.total_branches)
          <> ", consider splitting into smaller modules",
        details: "High module complexity makes the codebase harder to navigate. Consider splitting into focused modules.",
        location: glance.Span(0, 0),
      ),
    ]
    False -> []
  }
}
