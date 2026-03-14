import glance
import gleam/list
import gleam/option.{None, Some}
import glinter/rule.{type Rule, LintResult, Rule, Warning}

pub fn rule() -> Rule {
  Rule(
    name: "label_possible",
    default_severity: Warning,
    check_expression: None,
    check_statement: None,
    check_function: Some(check),
    check_module: None,
  )
}

fn check(func: glance.Function) -> List(rule.LintResult) {
  let params = func.parameters
  case list.length(params) >= 2 {
    False -> []
    True ->
      params
      |> list.filter_map(fn(param) {
        case param.label {
          Some(_) -> Error(Nil)
          None -> {
            let name = case param.name {
              glance.Named(n) -> n
              glance.Discarded(n) -> "_" <> n
            }
            Ok(LintResult(
              rule: "label_possible",
              severity: Warning,
              file: "",
              location: func.location,
              message: "Parameter '"
                <> name
                <> "' could benefit from a label for clarity at call sites",
            ))
          }
        }
      })
  }
}
