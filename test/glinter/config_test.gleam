import gleam/dict
import gleam/option.{None, Some}
import glinter/config

pub fn parse_empty_config_test() {
  let assert Ok(c) = config.parse("")
  let assert True = dict.size(c.rules) == 0
  let assert True = dict.size(c.ignore) == 0
}

pub fn parse_rules_section_test() {
  let toml =
    "[tools.glinter.rules]
avoid_panic = \"error\"
echo = \"off\"
"
  let assert Ok(c) = config.parse(toml)
  let assert True =
    dict.get(c.rules, "avoid_panic") == Ok(Some(config.SeverityError))
  let assert True = dict.get(c.rules, "echo") == Ok(None)
}

pub fn parse_warning_severity_test() {
  let toml =
    "[tools.glinter.rules]
echo = \"warning\"
"
  let assert Ok(c) = config.parse(toml)
  let assert True =
    dict.get(c.rules, "echo") == Ok(Some(config.SeverityWarning))
}

pub fn parse_ignore_section_test() {
  let toml =
    "[tools.glinter.ignore]
\"test/**/*.gleam\" = [\"avoid_panic\", \"echo\"]
"
  let assert Ok(c) = config.parse(toml)
  let assert True =
    dict.get(c.ignore, "test/**/*.gleam") == Ok(["avoid_panic", "echo"])
}

pub fn parse_gleam_toml_with_other_sections_test() {
  let toml =
    "name = \"myapp\"
version = \"1.0.0\"

[dependencies]
gleam_stdlib = \">= 0.44.0\"

[tools.glinter.rules]
echo = \"error\"
"
  let assert Ok(c) = config.parse(toml)
  let assert True = dict.get(c.rules, "echo") == Ok(Some(config.SeverityError))
}

pub fn default_config_test() {
  let c = config.default()
  let assert True = dict.size(c.rules) == 0
  let assert True = dict.size(c.ignore) == 0
  let assert False = c.stats
}

pub fn parse_stats_enabled_test() {
  let toml =
    "[tools.glinter]
stats = true
"
  let assert Ok(c) = config.parse(toml)
  let assert True = c.stats
}

pub fn parse_stats_disabled_test() {
  let toml =
    "[tools.glinter]
stats = false
"
  let assert Ok(c) = config.parse(toml)
  let assert False = c.stats
}

pub fn parse_stats_defaults_to_false_test() {
  let assert Ok(c) = config.parse("")
  let assert False = c.stats
}

pub fn parse_include_test() {
  let toml =
    "[tools.glinter]
include = [\"src/\", \"test/\"]
"
  let assert Ok(c) = config.parse(toml)
  let assert True = c.include == ["src/", "test/"]
}

pub fn parse_include_defaults_to_empty_test() {
  let assert Ok(c) = config.parse("")
  let assert True = c.include == []
}
