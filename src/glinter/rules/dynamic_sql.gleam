import glance
import gleam/list
import gleam/string
import glinter/rule.{type Rule, Off, Rule, RuleResult}

pub fn rule() -> Rule {
  Rule(
    name: "dynamic_sql",
    default_severity: Off,
    needs_collect: True,
    check: check,
  )
}

fn check(data: rule.ModuleData, _source: String) -> List(rule.RuleResult) {
  data.expressions |> list.flat_map(check_expression)
}

fn check_expression(expr: glance.Expression) -> List(rule.RuleResult) {
  case expr {
    glance.BinaryOperator(location, glance.Concatenate, left, right) ->
      case has_sql_keyword(left) || has_sql_keyword(right) {
        True -> [
          RuleResult(
            rule: "dynamic_sql",
            location: location,
            message: "String concatenation with SQL keywords detected — use parameterized queries instead",
          ),
        ]
        False -> []
      }
    _ -> []
  }
}

const sql_keywords = [
  "select ", "insert ", "update ", "delete ", "drop ", "alter ", "create ",
  " where ", " join ", " from ",
]

fn has_sql_keyword(expr: glance.Expression) -> Bool {
  case expr {
    glance.String(_, value) -> {
      let lower = string.lowercase(value)
      list.any(sql_keywords, fn(keyword) { string.contains(lower, keyword) })
    }
    _ -> False
  }
}
