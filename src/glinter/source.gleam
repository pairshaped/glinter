import gleam/bit_array
import gleam/list
import gleam/string

/// Convert byte offset to line number (1-indexed)
pub fn byte_offset_to_line(source: String, offset: Int) -> Int {
  let source_bytes = <<source:utf8>>
  let size = bit_array.byte_size(source_bytes)
  let clamped = case offset <= size {
    True -> offset
    False -> size
  }
  case bit_array.slice(source_bytes, 0, clamped) {
    Ok(bytes) ->
      case bit_array.to_string(bytes) {
        Ok(s) ->
          s
          |> string.split("\n")
          |> list.length()
        Error(_) -> 1
      }
    Error(_) -> 1
  }
}
