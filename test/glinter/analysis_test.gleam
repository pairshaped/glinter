import glance
import glinter/analysis

fn count(source: String) -> Int {
  let assert Ok(module) = glance.module(source)
  let assert [def, ..] = module.functions
  analysis.count_branches(def.definition.body)
}

pub fn counts_case_expression_test() {
  let assert True = count("pub fn f(x) { case x { _ -> 1 } }") == 1
}

pub fn counts_nested_case_test() {
  let assert True =
    count("pub fn f(x) { case x { _ -> case x { _ -> 1 } } }") == 2
}

pub fn counts_anonymous_fn_test() {
  let assert True = count("pub fn f() { fn() { 1 } }") == 1
}

pub fn counts_nested_block_test() {
  let assert True = count("pub fn f() { { 1 } }") == 1
}

pub fn counts_zero_for_simple_function_test() {
  let assert True = count("pub fn f() { 1 }") == 0
}

pub fn counts_multiple_branches_test() {
  let assert True =
    count(
      "pub fn f(x, y) {
      case x { _ -> 1 }
      case y { _ -> 2 }
      fn() { 3 }
    }",
    )
    == 3
}

pub fn counts_assert_message_branch_test() {
  let assert True =
    count("pub fn f(x) { assert x as 1 with case x { _ -> \"bad\" } }") == 1
}

pub fn counts_use_callback_branch_test() {
  let assert True =
    count(
      "pub fn f(result) {
      use value <- result.try(result)
      case value { _ -> value }
    }",
    )
    == 1
}

pub fn counts_branches_inside_collection_literals_test() {
  let assert True =
    count(
      "pub fn f(x) {
      #(case x { _ -> 1 }, [case x { _ -> 2 }, ..case x { _ -> [] }])
    }",
    )
    == 3
}

pub fn counts_branches_inside_record_update_fields_test() {
  let assert True =
    count(
      "pub fn f(user, x) {
      User(..user, name: case x { _ -> \"ok\" })
    }",
    )
    == 1
}

pub fn counts_branches_inside_function_capture_arguments_test() {
  let assert True =
    count(
      "pub fn f(x) {
      list.map(_, case x { _ -> 1 })
    }",
    )
    == 1
}

pub fn counts_branches_inside_panic_todo_and_echo_messages_test() {
  let assert True = count("pub fn f(x) { echo case x { _ -> 1 } }") == 1
  let assert True =
    count("pub fn f(x) { panic as case x { _ -> \"bad\" } }") == 1
  let assert True =
    count("pub fn f(x) { todo as case x { _ -> \"later\" } }") == 1
}
