import glance
import gleam/list
import gleeunit/should
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
  list.length(fns) |> should.equal(2)
}

pub fn excludes_main_function_test() {
  let assert Ok(module) =
    glance.module(
      "pub fn main() { Nil }
     pub fn other() { Nil }",
    )
  let defs = unused_exports.collect_pub_definitions(module)
  list.length(defs) |> should.equal(1)
}

pub fn collects_pub_constants_test() {
  let assert Ok(module) =
    glance.module(
      "pub const name = \"hello\"
     const private = \"world\"",
    )
  let defs = unused_exports.collect_pub_definitions(module)
  list.length(defs) |> should.equal(1)
  let assert [def] = defs
  def.kind |> should.equal(PubConstant)
  def.name |> should.equal("name")
}

pub fn collects_pub_types_test() {
  let assert Ok(module) =
    glance.module(
      "pub type Color { Red Green Blue }
     type Private { X }",
    )
  let defs = unused_exports.collect_pub_definitions(module)
  list.length(defs) |> should.equal(1)
  let assert [def] = defs
  def.kind |> should.equal(PubCustomType)
  def.name |> should.equal("Color")
}

pub fn collects_pub_type_aliases_test() {
  let assert Ok(module) = glance.module("pub type Name = String")
  let defs = unused_exports.collect_pub_definitions(module)
  list.length(defs) |> should.equal(1)
  let assert [def] = defs
  def.kind |> should.equal(PubTypeAlias)
}

// --- resolve_module_import tests ---

pub fn resolves_qualified_import_test() {
  let assert Ok(module) = glance.module("import myapp/users")
  let result = unused_exports.resolve_module_import(module, "myapp/users")
  result |> should.equal([unused_exports.QualifiedAs("users")])
}

pub fn resolves_aliased_import_test() {
  let assert Ok(module) = glance.module("import myapp/users as u")
  let result = unused_exports.resolve_module_import(module, "myapp/users")
  result |> should.equal([unused_exports.QualifiedAs("u")])
}

pub fn resolves_unqualified_value_imports_test() {
  let assert Ok(module) =
    glance.module("import myapp/users.{create, find_by_id}")
  let result = unused_exports.resolve_module_import(module, "myapp/users")
  should.be_true(list.contains(result, unused_exports.QualifiedAs("users")))
  should.be_true(list.contains(
    result,
    unused_exports.UnqualifiedValue("create"),
  ))
  should.be_true(list.contains(
    result,
    unused_exports.UnqualifiedValue("find_by_id"),
  ))
}

pub fn resolves_unqualified_type_imports_test() {
  let assert Ok(module) = glance.module("import myapp/users.{type User}")
  let result = unused_exports.resolve_module_import(module, "myapp/users")
  should.be_true(list.contains(result, unused_exports.UnqualifiedType("User")))
}

pub fn returns_empty_for_no_import_test() {
  let assert Ok(module) = glance.module("import other/module")
  let result = unused_exports.resolve_module_import(module, "myapp/users")
  result |> should.equal([])
}

pub fn resolves_discarded_alias_test() {
  let assert Ok(module) = glance.module("import myapp/users as _users")
  let result = unused_exports.resolve_module_import(module, "myapp/users")
  result |> should.equal([])
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
    )
  result |> should.be_true
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
    )
  result |> should.be_true
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
    )
  result |> should.be_true
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
    )
  result |> should.be_true
}

pub fn detects_unqualified_import_as_used_test() {
  let assert Ok(module) = glance.module("import myapp/users.{create}")
  let result =
    unused_exports.is_member_used_in(
      module,
      "myapp/users",
      "create",
      PubFunction,
    )
  result |> should.be_true
}

pub fn detects_unqualified_type_import_as_used_test() {
  let assert Ok(module) = glance.module("import myapp/users.{type User}")
  let result =
    unused_exports.is_member_used_in(
      module,
      "myapp/users",
      "User",
      PubCustomType,
    )
  result |> should.be_true
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
    )
  result |> should.be_true
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
    )
  result |> should.be_false
}

pub fn returns_false_when_not_imported_test() {
  let assert Ok(module) = glance.module("pub fn run() { Nil }")
  let result =
    unused_exports.is_member_used_in(
      module,
      "myapp/users",
      "create",
      PubFunction,
    )
  result |> should.be_false
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
    )
  result |> should.be_true
}

// --- check_unused_exports (orchestration) tests ---

pub fn detects_unused_pub_function_test() {
  let src_files = [
    #(
      "src/myapp/users.gleam",
      "myapp/users",
      "pub fn create() { Nil }
       pub fn unused_helper() { Nil }",
    ),
    #(
      "src/myapp/main.gleam",
      "myapp/main",
      "import myapp/users
       pub fn main() { users.create() }",
    ),
  ]
  let test_files = []
  let results =
    unused_exports.check_unused_exports(src_files, test_files, rule.Warning)
  list.length(results) |> should.equal(1)
  let assert [result] = results
  result.message
  |> should.equal(
    "Public function 'unused_helper' is never used by another module",
  )
  result.file |> should.equal("src/myapp/users.gleam")
}

pub fn all_exports_used_test() {
  let src_files = [
    #("src/myapp/users.gleam", "myapp/users", "pub fn create() { Nil }"),
    #(
      "src/myapp/main.gleam",
      "myapp/main",
      "import myapp/users
       pub fn main() { users.create() }",
    ),
  ]
  let test_files = []
  let results =
    unused_exports.check_unused_exports(src_files, test_files, rule.Warning)
  list.length(results) |> should.equal(0)
}

pub fn used_only_in_test_not_flagged_test() {
  let src_files = [
    #("src/myapp/users.gleam", "myapp/users", "pub fn create() { Nil }"),
  ]
  let test_files = [
    #(
      "test/users_test.gleam",
      "users_test",
      "import myapp/users
       pub fn create_test() { users.create() }",
    ),
  ]
  let results =
    unused_exports.check_unused_exports(src_files, test_files, rule.Warning)
  list.length(results) |> should.equal(0)
}
