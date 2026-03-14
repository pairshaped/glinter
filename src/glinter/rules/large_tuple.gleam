import glance
import gleam/int
import gleam/list
import gleam/option.{None, Some}
import glinter/rule.{type Rule, LintResult, Rule, Warning}

const max_tuple_size = 3

pub fn rule() -> Rule {
  Rule(
    name: "large_tuple",
    default_severity: Warning,
    check_expression: Some(check),
    check_statement: None,
    check_function: None,
    check_module: None,
  )
}

fn check(expr: glance.Expression) -> List(rule.LintResult) {
  case expr {
    glance.Tuple(location, elements) -> {
      let size = list.length(elements)
      case size > max_tuple_size {
        True -> [
          LintResult(
            rule: "large_tuple",
            severity: Warning,
            file: "",
            location: location,
            message: "Tuple has "
              <> int.to_string(size)
              <> " elements, consider using a custom type instead",
          ),
        ]
        False -> []
      }
    }
    _ -> []
  }
}
