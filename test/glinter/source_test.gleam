import glinter/source

pub fn strip_prefix_removes_prefix_test() {
  let assert True = source.strip_prefix("src/app.gleam", "src/") == "app.gleam"
}

pub fn strip_prefix_empty_prefix_returns_path_unchanged_test() {
  let assert True = source.strip_prefix("src/app.gleam", "") == "src/app.gleam"
}

pub fn strip_prefix_no_match_returns_path_unchanged_test() {
  let assert True =
    source.strip_prefix("src/app.gleam", "test/") == "src/app.gleam"
}

pub fn strip_prefix_exact_match_returns_empty_test() {
  let assert True = source.strip_prefix("src/", "src/") == ""
}

pub fn line_to_byte_offset_first_line_test() {
  let assert True =
    source.line_to_byte_offset("pub fn main() {\n  1\n}", 1) == 0
}

pub fn line_to_byte_offset_second_line_test() {
  // "pub fn main() {\n" = 16 bytes + 1 for newline = 17
  let assert True =
    source.line_to_byte_offset("pub fn main() {\n  1\n}", 2) == 16
}

pub fn line_to_byte_offset_third_line_test() {
  // "pub fn main() {\n  1\n" = 16 + 1(for newline) + 3 + 1(for newline) = 20... wait
  // "pub fn main() {\n" = 16 chars, including \n
  // "  1\n" = 4 chars
  // line 3 starts at 20
  let assert True =
    source.line_to_byte_offset("pub fn main() {\n  1\n}", 3) == 20
}

pub fn byte_offset_to_line_start_of_file_test() {
  let assert True =
    source.byte_offset_to_line("pub fn main() {\n  1\n}", 0) == 1
}

pub fn byte_offset_to_line_second_line_test() {
  // "pub fn main() {\n" = 16 bytes, offset 16 is start of "  1"
  let assert True =
    source.byte_offset_to_line("pub fn main() {\n  1\n}", 16) == 2
}

pub fn byte_offset_to_line_clamped_to_eof_test() {
  let assert True =
    source.byte_offset_to_line("pub fn main() {\n  1\n}", 9999) == 3
}

pub fn roundtrip_line_offset_line_test() {
  let source_code =
    "import gleam/list\nimport gleam/int\n\npub fn main() {\n  1\n}"
  let line = 4
  let offset = source.line_to_byte_offset(source_code, line)
  let result = source.byte_offset_to_line(source_code, offset)
  let assert True = result == line
}
