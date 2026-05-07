import glance
import gleam/list
import glinter/rule
import glinter/unused_exports.{
  PubConstant, PubCustomType, PubFunction, PubTypeAlias,
}

// --- collect_pub_definitions tests ---

pub fn collects_pub_functions_test() {
  let assert Ok(module) =
    glance.module(
      "pub fn greet() { Nil }
     fn private() { Nil }
     pub fn hello() { Nil }",
    )
  let defs = unused_exports.collect_pub_definitions(module)
  let fns =
    list.filter(defs, fn(d) {
      case d.kind {
        PubFunction -> True
        _ -> False
      }
    })
  let assert True = list.length(fns) == 2
}

pub fn excludes_main_function_test() {
  let assert Ok(module) =
    glance.module(
      "pub fn main() { Nil }
     pub fn other() { Nil }",
    )
  let defs = unused_exports.collect_pub_definitions(module)
  let assert True = list.length(defs) == 1
}

pub fn collects_pub_constants_test() {
  let assert Ok(module) =
    glance.module(
      "pub const name = \"hello\"
     const private = \"world\"",
    )
  let defs = unused_exports.collect_pub_definitions(module)
  let assert True = list.length(defs) == 1
  let assert [def] = defs
  let assert True = def.kind == PubConstant
  let assert True = def.name == "name"
}

pub fn collects_pub_types_test() {
  let assert Ok(module) =
    glance.module(
      "pub type Color { Red Green Blue }
     type Private { X }",
    )
  let defs = unused_exports.collect_pub_definitions(module)
  let assert True = list.length(defs) == 1
  let assert [def] = defs
  let assert True = def.kind == PubCustomType
  let assert True = def.name == "Color"
  let assert True = def.constructors == ["Red", "Green", "Blue"]
}

pub fn collects_pub_type_aliases_test() {
  let assert Ok(module) = glance.module("pub type Name = String")
  let defs = unused_exports.collect_pub_definitions(module)
  let assert True = list.length(defs) == 1
  let assert [def] = defs
  let assert True = def.kind == PubTypeAlias
}

// --- resolve_module_import tests ---

pub fn resolves_qualified_import_test() {
  let assert Ok(module) = glance.module("import myapp/users")
  let result = unused_exports.resolve_module_import(module, "myapp/users")
  let assert True = result == [unused_exports.QualifiedAs("users")]
}

pub fn resolves_aliased_import_test() {
  let assert Ok(module) = glance.module("import myapp/users as u")
  let result = unused_exports.resolve_module_import(module, "myapp/users")
  let assert True = result == [unused_exports.QualifiedAs("u")]
}

pub fn resolves_unqualified_value_imports_test() {
  let assert Ok(module) =
    glance.module("import myapp/users.{create, find_by_id}")
  let result = unused_exports.resolve_module_import(module, "myapp/users")
  let assert True = list.contains(result, unused_exports.QualifiedAs("users"))
  let assert True =
    list.contains(result, unused_exports.UnqualifiedValue("create"))
  let assert True =
    list.contains(result, unused_exports.UnqualifiedValue("find_by_id"))
}

pub fn resolves_unqualified_type_imports_test() {
  let assert Ok(module) = glance.module("import myapp/users.{type User}")
  let result = unused_exports.resolve_module_import(module, "myapp/users")
  let assert True =
    list.contains(result, unused_exports.UnqualifiedType("User"))
}

pub fn returns_empty_for_no_import_test() {
  let assert Ok(module) = glance.module("import other/module")
  let result = unused_exports.resolve_module_import(module, "myapp/users")
  let assert True = result == []
}

pub fn resolves_discarded_alias_test() {
  let assert Ok(module) = glance.module("import myapp/users as _users")
  let result = unused_exports.resolve_module_import(module, "myapp/users")
  let assert True = result == []
}

// --- is_member_used_in tests ---

pub fn detects_qualified_function_call_test() {
  let assert Ok(module) =
    glance.module(
      "import myapp/users
     pub fn run() { users.create() }",
    )
  let result =
    unused_exports.is_member_used_in(
      module,
      "myapp/users",
      "create",
      PubFunction,
      [],
    )
  let assert True = result
}

pub fn detects_qualified_constant_access_test() {
  let assert Ok(module) =
    glance.module(
      "import myapp/config
     pub fn run() { config.timeout }",
    )
  let result =
    unused_exports.is_member_used_in(
      module,
      "myapp/config",
      "timeout",
      PubConstant,
      [],
    )
  let assert True = result
}

pub fn detects_qualified_type_in_annotation_test() {
  let assert Ok(module) =
    glance.module(
      "import myapp/users
     pub fn run(u: users.User) { u }",
    )
  let result =
    unused_exports.is_member_used_in(
      module,
      "myapp/users",
      "User",
      PubCustomType,
      [],
    )
  let assert True = result
}

pub fn detects_qualified_constructor_in_pattern_test() {
  let assert Ok(module) =
    glance.module(
      "import myapp/color
     pub fn run(c) { case c { color.Red -> 1 _ -> 0 } }",
    )
  let result =
    unused_exports.is_member_used_in(
      module,
      "myapp/color",
      "Red",
      PubCustomType,
      [],
    )
  let assert True = result
}

pub fn detects_unqualified_import_as_used_test() {
  let assert Ok(module) = glance.module("import myapp/users.{create}")
  let result =
    unused_exports.is_member_used_in(
      module,
      "myapp/users",
      "create",
      PubFunction,
      [],
    )
  let assert True = result
}

pub fn detects_unqualified_type_import_as_used_test() {
  let assert Ok(module) = glance.module("import myapp/users.{type User}")
  let result =
    unused_exports.is_member_used_in(
      module,
      "myapp/users",
      "User",
      PubCustomType,
      [],
    )
  let assert True = result
}

pub fn detects_aliased_module_access_test() {
  let assert Ok(module) =
    glance.module(
      "import myapp/users as u
     pub fn run() { u.create() }",
    )
  let result =
    unused_exports.is_member_used_in(
      module,
      "myapp/users",
      "create",
      PubFunction,
      [],
    )
  let assert True = result
}

pub fn returns_false_when_not_used_test() {
  let assert Ok(module) =
    glance.module(
      "import myapp/users
     pub fn run() { Nil }",
    )
  let result =
    unused_exports.is_member_used_in(
      module,
      "myapp/users",
      "create",
      PubFunction,
      [],
    )
  let assert False = result
}

pub fn returns_false_when_not_imported_test() {
  let assert Ok(module) = glance.module("pub fn run() { Nil }")
  let result =
    unused_exports.is_member_used_in(
      module,
      "myapp/users",
      "create",
      PubFunction,
      [],
    )
  let assert False = result
}

pub fn detects_record_update_test() {
  let assert Ok(module) =
    glance.module(
      "import myapp/users
     pub fn run(u) { users.User(..u, name: \"new\") }",
    )
  let result =
    unused_exports.is_member_used_in(
      module,
      "myapp/users",
      "User",
      PubCustomType,
      [],
    )
  let assert True = result
}

// --- check_unused_exports (orchestration) tests ---

fn parse(
  path path: String,
  module_path module_path: String,
  source source: String,
) -> #(String, String, glance.Module) {
  let assert Ok(module) = glance.module(source)
  #(path, module_path, module)
}

pub fn detects_unused_pub_function_test() {
  let src_files = [
    parse(
      path: "src/myapp/users.gleam",
      module_path: "myapp/users",
      source: "pub fn create() { Nil }
       pub fn unused_helper() { Nil }",
    ),
    parse(
      path: "src/myapp/main.gleam",
      module_path: "myapp/main",
      source: "import myapp/users
       pub fn main() { users.create() }",
    ),
  ]
  let test_files = []
  let results =
    unused_exports.check_unused_exports(
      parsed_src: src_files,
      parsed_test: test_files,
      severity: rule.Warning,
    )
  let assert True = list.length(results) == 1
  let assert [result] = results
  let assert True =
    result.message
    == "Public function 'unused_helper' is never used by another module"
  let assert True = result.file == "src/myapp/users.gleam"
}

pub fn all_exports_used_test() {
  let src_files = [
    parse(
      path: "src/myapp/users.gleam",
      module_path: "myapp/users",
      source: "pub fn create() { Nil }",
    ),
    parse(
      path: "src/myapp/main.gleam",
      module_path: "myapp/main",
      source: "import myapp/users
       pub fn main() { users.create() }",
    ),
  ]
  let test_files = []
  let results =
    unused_exports.check_unused_exports(
      parsed_src: src_files,
      parsed_test: test_files,
      severity: rule.Warning,
    )
  let assert True = results == []
}

pub fn used_only_in_test_not_flagged_test() {
  let src_files = [
    parse(
      path: "src/myapp/users.gleam",
      module_path: "myapp/users",
      source: "pub fn create() { Nil }",
    ),
  ]
  let test_files = [
    parse(
      path: "test/users_test.gleam",
      module_path: "users_test",
      source: "import myapp/users
       pub fn create_test() { users.create() }",
    ),
  ]
  let results =
    unused_exports.check_unused_exports(
      parsed_src: src_files,
      parsed_test: test_files,
      severity: rule.Warning,
    )
  let assert True = results == []
}

pub fn custom_type_with_constructor_only_usage_not_flagged_test() {
  // A pub custom type whose constructors (but not the type name itself) are
  // used in another module should NOT be flagged as unused.
  let src_files = [
    parse(
      path: "src/myapp/color.gleam",
      module_path: "myapp/color",
      source: "pub type Color { Red Green Blue }",
    ),
    parse(
      path: "src/myapp/main.gleam",
      module_path: "myapp/main",
      source: "import myapp/color
pub fn main(c) { case c { color.Red -> 1 _ -> 0 } }",
    ),
  ]
  let test_files = []
  let results =
    unused_exports.check_unused_exports(
      parsed_src: src_files,
      parsed_test: test_files,
      severity: rule.Warning,
    )
  let assert True = results == []
}

pub fn custom_type_with_record_constructor_usage_not_flagged_test() {
  // A pub custom type used via record construction in another module should
  // NOT be flagged as unused.
  let src_files = [
    parse(
      path: "src/myapp/users.gleam",
      module_path: "myapp/users",
      source: "pub type User { User(name: String) }",
    ),
    parse(
      path: "src/myapp/main.gleam",
      module_path: "myapp/main",
      source: "import myapp/users
pub fn main(u) { users.User(..u, name: \"new\") }",
    ),
  ]
  let test_files = []
  let results =
    unused_exports.check_unused_exports(
      parsed_src: src_files,
      parsed_test: test_files,
      severity: rule.Warning,
    )
  let assert True = results == []
}

pub fn custom_type_with_unqualified_constructor_import_not_flagged_test() {
  let src_files = [
    parse(
      path: "src/myapp/color.gleam",
      module_path: "myapp/color",
      source: "pub type Color { Red Green Blue }",
    ),
    parse(
      path: "src/myapp/main.gleam",
      module_path: "myapp/main",
      source: "import myapp/color.{Red}
pub fn main(c) { case c { Red -> 1 _ -> 0 } }",
    ),
  ]
  let results =
    unused_exports.check_unused_exports(
      parsed_src: src_files,
      parsed_test: [],
      severity: rule.Warning,
    )
  let assert False =
    list.any(results, fn(result) {
      result.message == "Public type 'Color' is never used by another module"
    })
}

pub fn custom_type_used_in_public_interface_not_flagged_test() {
  let src_files = [
    parse(
      path: "src/myapp/api.gleam",
      module_path: "myapp/api",
      source: "pub type User { User(id: Int) }
pub fn find() -> User { User(1) }",
    ),
  ]
  let results =
    unused_exports.check_unused_exports(
      parsed_src: src_files,
      parsed_test: [],
      severity: rule.Warning,
    )
  let assert False =
    list.any(results, fn(result) {
      result.message == "Public type 'User' is never used by another module"
    })
}

// --- @internal annotation tests ---

pub fn internal_function_not_flagged_as_unused_test() {
  // An @internal function with no external callers should NOT be flagged
  // as "unused" because @internal means it's intentionally public for
  // internal/testing use.
  let src_files = [
    parse(
      path: "src/myapp/users.gleam",
      module_path: "myapp/users",
      source: "@internal
pub fn helper() { Nil }",
    ),
  ]
  let test_files = []
  let results =
    unused_exports.check_unused_exports(
      parsed_src: src_files,
      parsed_test: test_files,
      severity: rule.Warning,
    )
  let assert True = results == []
}

pub fn internal_function_used_externally_flagged_as_misuse_test() {
  // An @internal function that IS used by another module should be flagged
  // because the annotation is likely a leftover.
  let src_files = [
    parse(
      path: "src/myapp/users.gleam",
      module_path: "myapp/users",
      source: "@internal
pub fn helper() { Nil }",
    ),
    parse(
      path: "src/myapp/main.gleam",
      module_path: "myapp/main",
      source: "import myapp/users
pub fn main() { users.helper() }",
    ),
  ]
  let test_files = []
  let results =
    unused_exports.check_unused_exports(
      parsed_src: src_files,
      parsed_test: test_files,
      severity: rule.Warning,
    )
  let assert True = list.length(results) == 1
  let assert [result] = results
  let assert True =
    result.message
    == "Public function 'helper' has @internal but is used externally — annotation may be a leftover"
  let assert True = result.file == "src/myapp/users.gleam"
}

pub fn internal_function_not_used_not_flagged_as_misuse_test() {
  // An @internal function that is NOT used should produce NO lint results
  // at all (not flagged as unused, not flagged as misused).
  let src_files = [
    parse(
      path: "src/myapp/users.gleam",
      module_path: "myapp/users",
      source: "@internal
pub fn helper() { Nil }",
    ),
    parse(
      path: "src/myapp/main.gleam",
      module_path: "myapp/main",
      source: "pub fn main() { Nil }",
    ),
  ]
  let test_files = []
  let results =
    unused_exports.check_unused_exports(
      parsed_src: src_files,
      parsed_test: test_files,
      severity: rule.Warning,
    )
  let assert True = results == []
}

pub fn regular_pub_fn_still_flagged_when_unused_test() {
  // Non-@internal public functions should still be flagged as unused (regression).
  let src_files = [
    parse(
      path: "src/myapp/users.gleam",
      module_path: "myapp/users",
      source: "pub fn helper() { Nil }
        pub fn used_one() { Nil }",
    ),
    parse(
      path: "src/myapp/main.gleam",
      module_path: "myapp/main",
      source: "import myapp/users
pub fn main() { users.used_one() }",
    ),
  ]
  let test_files = []
  let results =
    unused_exports.check_unused_exports(
      parsed_src: src_files,
      parsed_test: test_files,
      severity: rule.Warning,
    )
  let assert True = list.length(results) == 1
  let assert [result] = results
  let assert True =
    result.message == "Public function 'helper' is never used by another module"
}

pub fn internal_function_main_still_excluded_test() {
  // @internal on main should still be excluded (main is always skipped).
  let src_files = [
    parse(
      path: "src/myapp/app.gleam",
      module_path: "myapp/app",
      source: "@internal
pub fn main() { Nil }",
    ),
  ]
  let test_files = []
  let results =
    unused_exports.check_unused_exports(
      parsed_src: src_files,
      parsed_test: test_files,
      severity: rule.Warning,
    )
  let assert True = results == []
}

pub fn private_function_with_internal_flagged_test() {
  // @internal on a private function is a compiler diagnostic, not glinter's job.
  let src_files = [
    parse(
      path: "src/myapp/users.gleam",
      module_path: "myapp/users",
      source: "@internal
fn helper() { Nil }",
    ),
  ]
  let test_files = []
  let results =
    unused_exports.check_unused_exports(
      parsed_src: src_files,
      parsed_test: test_files,
      severity: rule.Warning,
    )
  let assert True = results == []
}

pub fn private_type_with_internal_flagged_test() {
  // @internal on a private type is a compiler diagnostic, not glinter's job.
  let src_files = [
    parse(
      path: "src/myapp/users.gleam",
      module_path: "myapp/users",
      source: "@internal
type Helper { X }",
    ),
  ]
  let test_files = []
  let results =
    unused_exports.check_unused_exports(
      parsed_src: src_files,
      parsed_test: test_files,
      severity: rule.Warning,
    )
  let assert True = results == []
}
