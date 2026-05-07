import glance
import glinter/helpers

pub fn starts_uppercase_true_test() {
  let assert True = helpers.starts_uppercase("Result")
  let assert True = helpers.starts_uppercase("Ok")
  let assert True = helpers.starts_uppercase("A")
}

pub fn starts_uppercase_false_test() {
  let assert False = helpers.starts_uppercase("snake_case")
  let assert False = helpers.starts_uppercase("camelCase")
  let assert False = helpers.starts_uppercase("")
}

pub fn starts_lowercase_true_test() {
  let assert True = helpers.starts_lowercase("result")
  let assert True = helpers.starts_lowercase("ok")
  let assert True = helpers.starts_lowercase("a")
}

pub fn starts_lowercase_false_test() {
  let assert False = helpers.starts_lowercase("SnakeCase")
  let assert False = helpers.starts_lowercase("A")
  let assert False = helpers.starts_lowercase("")
}

pub fn has_all_external_targets_both_targets_test() {
  let assert Ok(module) =
    glance.module(
      "@external(erlang, \"mod\", \"fn\")
@external(javascript, \"mod.mjs\", \"fn\")
pub fn my_ffi() { panic }",
    )
  let assert [def] = module.functions
  let assert True = helpers.has_all_external_targets(def)
}

pub fn has_all_external_targets_only_erlang_test() {
  let assert Ok(module) =
    glance.module(
      "@external(erlang, \"mod\", \"fn\")
pub fn my_ffi() { panic }",
    )
  let assert [def] = module.functions
  let assert False = helpers.has_all_external_targets(def)
}

pub fn has_all_external_targets_only_javascript_test() {
  let assert Ok(module) =
    glance.module(
      "@external(javascript, \"mod.mjs\", \"fn\")
pub fn my_ffi() { panic }",
    )
  let assert [def] = module.functions
  let assert False = helpers.has_all_external_targets(def)
}

pub fn has_all_external_targets_no_external_test() {
  let assert Ok(module) = glance.module("pub fn normal() { 1 }")
  let assert [def] = module.functions
  let assert False = helpers.has_all_external_targets(def)
}
