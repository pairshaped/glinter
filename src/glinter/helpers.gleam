import glance
import gleam/list
import gleam/string

/// Check if a function has @external annotations covering all compile targets.
/// Used by rules that need to suppress warnings in @external fallback bodies
/// (the Gleam body is unreachable when externals cover all compile targets).
pub fn has_all_external_targets(
  definition: glance.Definition(glance.Function),
) -> Bool {
  let targets =
    definition.attributes
    |> list.filter_map(fn(attr) {
      case attr {
        glance.Attribute(
          name: "external",
          arguments: [glance.Variable(_, target), ..],
        ) -> Ok(target)
        _ -> Error(Nil)
      }
    })
  list.contains(targets, "erlang") && list.contains(targets, "javascript")
}

pub fn starts_uppercase(name: String) -> Bool {
  case string.first(name) {
    Ok(c) -> c == string.uppercase(c)
    Error(_) -> False
  }
}

pub fn starts_lowercase(name: String) -> Bool {
  case string.first(name) {
    Ok(c) -> c == string.lowercase(c)
    Error(_) -> False
  }
}
