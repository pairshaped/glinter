import glance
import gleam/list
import gleam/option.{None, Some}
import glinter/rule.{type V2Rule, RuleResult, V2Rule, Warning}

pub fn rule() -> V2Rule {
  V2Rule(
    name: "missing_type_annotation",
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
  let return_result = case func.return {
    None -> [
      RuleResult(
        rule: "missing_type_annotation",
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
          Ok(RuleResult(
            rule: "missing_type_annotation",
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
