import gleam/dict
import gleam/option.{None, Some}
import glinter/config
import glinter/rule

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

pub fn parse_exclude_test() {
  let toml =
    "[tools.glinter]
exclude = [\"src/generated/\", \"test/fixtures/\"]
"
  let assert Ok(c) = config.parse(toml)
  let assert True = c.exclude == ["src/generated/", "test/fixtures/"]
}

pub fn parse_exclude_defaults_to_empty_test() {
  let assert Ok(c) = config.parse("")
  let assert True = c.exclude == []
}

pub fn parse_warnings_as_errors_enabled_test() {
  let toml =
    "[tools.glinter]
warnings_as_errors = true
"
  let assert Ok(c) = config.parse(toml)
  let assert True = c.warnings_as_errors
}

pub fn parse_warnings_as_errors_disabled_test() {
  let toml =
    "[tools.glinter]
warnings_as_errors = false
"
  let assert Ok(c) = config.parse(toml)
  let assert False = c.warnings_as_errors
}

pub fn parse_warnings_as_errors_defaults_to_false_test() {
  let assert Ok(c) = config.parse("")
  let assert False = c.warnings_as_errors
}

pub fn resolve_severity_explicitly_off_test() {
  let cfg =
    config.default()
    |> with_rule("my_rule", None)
  let result =
    config.resolve_severity(cfg, "my_rule", fn() { Ok(rule.Warning) })
  let assert True = result == Error(Nil)
}

pub fn resolve_severity_explicitly_error_test() {
  let cfg =
    config.default()
    |> with_rule("my_rule", Some(config.SeverityError))
  let result =
    config.resolve_severity(cfg, "my_rule", fn() { Ok(rule.Warning) })
  let assert True = result == Ok(rule.Error)
}

pub fn resolve_severity_explicitly_warning_test() {
  let cfg =
    config.default()
    |> with_rule("my_rule", Some(config.SeverityWarning))
  let result = config.resolve_severity(cfg, "my_rule", fn() { Ok(rule.Error) })
  let assert True = result == Ok(rule.Warning)
}

pub fn resolve_severity_uses_default_when_not_configured_test() {
  let cfg = config.default()
  let result = config.resolve_severity(cfg, "my_rule", fn() { Ok(rule.Error) })
  let assert True = result == Ok(rule.Error)
}

pub fn resolve_severity_default_returns_off_test() {
  let cfg = config.default()
  let result = config.resolve_severity(cfg, "my_rule", fn() { Error(Nil) })
  let assert True = result == Error(Nil)
}

fn with_rule(
  cfg: config.Config,
  name: String,
  override: option.Option(config.SeverityOverride),
) -> config.Config {
  config.Config(..cfg, rules: dict.insert(cfg.rules, name, override))
}
