import gleam/dict.{type Dict}
import gleam/list
import gleam/option.{type Option, None, Some}
import tom

pub type SeverityOverride {
  SeverityError
  SeverityWarning
}

pub type Config {
  Config(
    rules: Dict(String, Option(SeverityOverride)),
    ignore: Dict(String, List(String)),
    include: List(String),
    exclude: List(String),
    stats: Bool,
    warnings_as_errors: Bool,
  )
}

pub fn default() -> Config {
  Config(
    rules: dict.new(),
    ignore: dict.new(),
    include: [],
    exclude: [],
    stats: False,
    warnings_as_errors: False,
  )
}

pub fn parse(toml_string: String) -> Result(Config, String) {
  case tom.parse(toml_string) {
    Error(_) -> Error("Failed to parse config file")
    Ok(parsed) -> {
      let rules = parse_rules(parsed)
      let ignore = parse_ignore(parsed)
      let include = parse_string_array(parsed, "include")
      let exclude = parse_string_array(parsed, "exclude")
      let stats = parse_stats(parsed)
      let warnings_as_errors = parse_warnings_as_errors(parsed)
      Ok(Config(
        rules: rules,
        ignore: ignore,
        include: include,
        exclude: exclude,
        stats: stats,
        warnings_as_errors: warnings_as_errors,
      ))
    }
  }
}

fn parse_rules(
  parsed: Dict(String, tom.Toml),
) -> Dict(String, Option(SeverityOverride)) {
  case tom.get_table(parsed, ["tools", "glinter", "rules"]) {
    Error(_) -> dict.new()
    Ok(rules_table) -> {
      rules_table
      |> dict.to_list()
      |> list.filter_map(fn(pair) {
        let #(key, value) = pair
        case value {
          tom.String(s) ->
            case s {
              "error" -> Ok(#(key, Some(SeverityError)))
              "warning" -> Ok(#(key, Some(SeverityWarning)))
              "off" -> Ok(#(key, None))
              _ -> Error(Nil)
            }
          _ -> Error(Nil)
        }
      })
      |> dict.from_list()
    }
  }
}

fn parse_stats(parsed: Dict(String, tom.Toml)) -> Bool {
  case tom.get_bool(parsed, ["tools", "glinter", "stats"]) {
    Ok(value) -> value
    Error(_) -> False
  }
}

fn parse_string_array(
  parsed: Dict(String, tom.Toml),
  key: String,
) -> List(String) {
  case tom.get_array(parsed, ["tools", "glinter", key]) {
    Error(_) -> []
    Ok(items) ->
      items
      |> list.filter_map(fn(item) {
        case item {
          tom.String(s) -> Ok(s)
          _ -> Error(Nil)
        }
      })
  }
}

fn parse_warnings_as_errors(parsed: Dict(String, tom.Toml)) -> Bool {
  case tom.get_bool(parsed, ["tools", "glinter", "warnings_as_errors"]) {
    Ok(value) -> value
    Error(_) -> False
  }
}

fn parse_ignore(parsed: Dict(String, tom.Toml)) -> Dict(String, List(String)) {
  case tom.get_table(parsed, ["tools", "glinter", "ignore"]) {
    Error(_) -> dict.new()
    Ok(ignore_table) -> {
      ignore_table
      |> dict.to_list()
      |> list.filter_map(fn(pair) {
        let #(key, value) = pair
        case value {
          tom.Array(items) -> {
            let strings =
              items
              |> list.filter_map(fn(item) {
                case item {
                  tom.String(s) -> Ok(s)
                  _ -> Error(Nil)
                }
              })
            Ok(#(key, strings))
          }
          _ -> Error(Nil)
        }
      })
      |> dict.from_list()
    }
  }
}
