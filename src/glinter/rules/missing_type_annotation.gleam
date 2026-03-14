import glance
import gleam/list
import gleam/option.{None, Some}
import glinter/rule.{type Rule, LintResult, Rule, Warning}

pub fn rule() -> Rule {
  Rule(
    name: "missing_type_annotation",
    default_severity: Warning,
    check_expression: None,
    check_statement: None,
    check_function: Some(check),
    check_module: None,
  )
}

fn check(func: glance.Function) -> List(rule.LintResult) {
  let return_result = case func.return {
    None -> [
      LintResult(
        rule: "missing_type_annotation",
        severity: Warning,
        file: "",
        location: func.location,
        message: "Function '"
          <> func.name
          <> "' is missing a return type annotation",
      ),
    ]
    Some(_) -> []
  }

  let param_results =
    func.parameters
    |> list.filter_map(fn(param) {
      case param.type_ {
        None -> {
          let name = case param.name {
            glance.Named(n) -> n
            glance.Discarded(n) -> "_" <> n
          }
          Ok(LintResult(
            rule: "missing_type_annotation",
            severity: Warning,
            file: "",
            location: func.location,
            message: "Function '"
              <> func.name
              <> "' has untyped parameter '"
              <> name
              <> "'",
          ))
        }
        Some(_) -> Error(Nil)
      }
    })

  list.append(return_result, param_results)
}
