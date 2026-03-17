import glance
import gleam/list
import gleam/option.{Some}
import glinter/rule.{type V2Rule, RuleResult, V2Rule, Warning}

pub fn rule() -> V2Rule {
  V2Rule(
    name: "stringly_typed_error",
    default_severity: Warning,
    needs_collect: False,
    check: check,
  )
}

fn check(data: rule.ModuleData, _source: String) -> List(rule.RuleResult) {
  data.module.functions
  |> list.filter_map(fn(def) {
    let func = def.definition
    case func.return {
      Some(glance.NamedType(_, "Result", _, [_, error_type])) ->
        case is_string_type(error_type) {
          True ->
            Ok(RuleResult(
              rule: "stringly_typed_error",
              location: func.location,
              message: "Function '"
                <> func.name
                <> "' uses String as error type — use a custom error type instead",
            ))
          False -> Error(Nil)
        }
      _ -> Error(Nil)
    }
  })
}

fn is_string_type(t: glance.Type) -> Bool {
  case t {
    glance.NamedType(_, "String", _, []) -> True
    _ -> False
  }
}
