/// NOTE: Expression/pattern/type tree traversal here must stay in sync with
/// analysis.gleam, rules/deep_nesting.gleam, and rules/missing_labels.gleam
/// when glance adds new variants.
import glance.{
  type Expression, type Module, type Pattern, type Statement, type Type,
  Constant, CustomType, Definition, Function, Public, TypeAlias,
}
import gleam/list
import gleam/option.{None, Some}
import gleam/string
import glinter/rule

pub type PubKind {
  PubFunction
  PubConstant
  PubCustomType
  PubTypeAlias
}

pub type PubDefinition {
  PubDefinition(name: String, kind: PubKind, location: glance.Span)
}

pub type ImportResolution {
  QualifiedAs(String)
  UnqualifiedValue(String)
  UnqualifiedType(String)
}

// --- Collect pub definitions from a module ---

pub fn collect_pub_definitions(module: Module) -> List(PubDefinition) {
  let functions =
    module.functions
    |> list.filter_map(fn(def) {
      let Definition(
        _,
        Function(name: name, publicity: publicity, location: location, ..),
      ) = def
      case publicity, name {
        Public, "main" -> Error(Nil)
        Public, _ ->
          Ok(PubDefinition(name: name, kind: PubFunction, location: location))
        _, _ -> Error(Nil)
      }
    })

  let constants =
    module.constants
    |> list.filter_map(fn(def) {
      let Definition(
        _,
        Constant(name: name, publicity: publicity, location: location, ..),
      ) = def
      case publicity {
        Public ->
          Ok(PubDefinition(name: name, kind: PubConstant, location: location))
        _ -> Error(Nil)
      }
    })

  let types =
    module.custom_types
    |> list.filter_map(fn(def) {
      let Definition(
        _,
        CustomType(name: name, publicity: publicity, location: location, ..),
      ) = def
      case publicity {
        Public ->
          Ok(PubDefinition(name: name, kind: PubCustomType, location: location))
        _ -> Error(Nil)
      }
    })

  let aliases =
    module.type_aliases
    |> list.filter_map(fn(def) {
      let Definition(
        _,
        TypeAlias(name: name, publicity: publicity, location: location, ..),
      ) = def
      case publicity {
        Public ->
          Ok(PubDefinition(name: name, kind: PubTypeAlias, location: location))
        _ -> Error(Nil)
      }
    })

  list.flatten([functions, constants, types, aliases])
}

// --- Import resolution ---

pub fn resolve_module_import(
  consumer: Module,
  module_path: String,
) -> List(ImportResolution) {
  consumer.imports
  |> list.flat_map(fn(def) {
    let Definition(_, import_) = def
    case import_.module == module_path {
      False -> []
      True -> {
        let qualified = case import_.alias {
          Some(glance.Named(alias)) -> [QualifiedAs(alias)]
          Some(glance.Discarded(_)) -> []
          None -> {
            let assert Ok(last) = string.split(module_path, "/") |> list.last
            [QualifiedAs(last)]
          }
        }
        let unqualified_values =
          import_.unqualified_values
          |> list.map(fn(uq) { UnqualifiedValue(uq.name) })
        let unqualified_types =
          import_.unqualified_types
          |> list.map(fn(uq) { UnqualifiedType(uq.name) })
        list.flatten([qualified, unqualified_values, unqualified_types])
      }
    }
  })
}

// --- Check if a pub member is used in a consuming module ---

pub fn is_member_used_in(
  consumer: Module,
  module_path: String,
  member_name: String,
  member_kind: PubKind,
) -> Bool {
  let resolutions = resolve_module_import(consumer, module_path)
  case resolutions {
    [] -> False
    _ -> {
      // Check unqualified imports first (short-circuit)
      let is_unqualified =
        list.any(resolutions, fn(r) {
          case r, member_kind {
            UnqualifiedValue(name), PubFunction
            | UnqualifiedValue(name), PubConstant
            -> name == member_name
            UnqualifiedType(name), PubCustomType
            | UnqualifiedType(name), PubTypeAlias
            -> name == member_name
            _, _ -> False
          }
        })
      case is_unqualified {
        True -> True
        False -> {
          let aliases =
            list.filter_map(resolutions, fn(r) {
              case r {
                QualifiedAs(alias) -> Ok(alias)
                _ -> Error(Nil)
              }
            })
          search_module_for_reference(consumer, aliases, member_name)
        }
      }
    }
  }
}

fn search_module_for_reference(
  module: Module,
  aliases: List(String),
  member_name: String,
) -> Bool {
  list.any(module.functions, fn(def) {
    let Definition(_, func) = def
    search_statements(func.body, aliases, member_name)
    || search_function_types(func, aliases, member_name)
  })
  || list.any(module.constants, fn(def) {
    let Definition(_, Constant(value: value, annotation: annotation, ..)) = def
    search_expression(value, aliases, member_name)
    || case annotation {
      Some(t) -> search_type(t, aliases, member_name)
      None -> False
    }
  })
  || list.any(module.custom_types, fn(def) {
    let Definition(_, CustomType(variants: variants, ..)) = def
    list.any(variants, fn(variant) {
      list.any(variant.fields, fn(field) {
        case field {
          glance.LabelledVariantField(item: t, ..) ->
            search_type(t, aliases, member_name)
          glance.UnlabelledVariantField(item: t) ->
            search_type(t, aliases, member_name)
        }
      })
    })
  })
  || list.any(module.type_aliases, fn(def) {
    let Definition(_, TypeAlias(aliased: t, ..)) = def
    search_type(t, aliases, member_name)
  })
}

fn search_function_types(
  func: glance.Function,
  aliases: List(String),
  member_name: String,
) -> Bool {
  list.any(func.parameters, fn(param) {
    case param.type_ {
      Some(t) -> search_type(t, aliases, member_name)
      None -> False
    }
  })
  || case func.return {
    Some(t) -> search_type(t, aliases, member_name)
    None -> False
  }
}

fn search_statements(
  stmts: List(Statement),
  aliases: List(String),
  member_name: String,
) -> Bool {
  list.any(stmts, fn(stmt) { search_statement(stmt, aliases, member_name) })
}

fn search_statement(
  stmt: Statement,
  aliases: List(String),
  member_name: String,
) -> Bool {
  case stmt {
    glance.Expression(expr) -> search_expression(expr, aliases, member_name)
    glance.Assignment(value: expr, annotation: annotation, pattern: pattern, ..) ->
      search_expression(expr, aliases, member_name)
      || search_pattern(pattern, aliases, member_name)
      || case annotation {
        Some(t) -> search_type(t, aliases, member_name)
        None -> False
      }
    glance.Use(function: expr, ..) ->
      search_expression(expr, aliases, member_name)
    glance.Assert(expression: expr, message: message, ..) ->
      search_expression(expr, aliases, member_name)
      || case message {
        Some(m) -> search_expression(m, aliases, member_name)
        None -> False
      }
  }
}

fn search_expression(
  expr: Expression,
  aliases: List(String),
  member_name: String,
) -> Bool {
  case expr {
    // Qualified access: module.member
    glance.FieldAccess(_, container, label) ->
      case container {
        glance.Variable(_, module_name) ->
          label == member_name && list.contains(aliases, module_name)
        _ -> False
      }
      || search_expression(container, aliases, member_name)

    // Record update: module.Constructor(..record, field: value)
    glance.RecordUpdate(_, Some(module_name), constructor, record, fields) ->
      { constructor == member_name && list.contains(aliases, module_name) }
      || search_expression(record, aliases, member_name)
      || list.any(fields, fn(field) {
        case field.item {
          Some(e) -> search_expression(e, aliases, member_name)
          None -> False
        }
      })

    // Recurse into children
    glance.Call(_, function, arguments) ->
      search_expression(function, aliases, member_name)
      || list.any(arguments, fn(field) {
        case field {
          glance.LabelledField(_, _, item) ->
            search_expression(item, aliases, member_name)
          glance.UnlabelledField(item) ->
            search_expression(item, aliases, member_name)
          glance.ShorthandField(_, _) -> False
        }
      })

    glance.Block(_, stmts) -> search_statements(stmts, aliases, member_name)

    glance.Case(_, subjects, clauses) ->
      list.any(subjects, fn(s) { search_expression(s, aliases, member_name) })
      || list.any(clauses, fn(clause) {
        search_expression(clause.body, aliases, member_name)
        || list.any(clause.patterns, fn(pattern_list) {
          list.any(pattern_list, fn(p) {
            search_pattern(p, aliases, member_name)
          })
        })
        || case clause.guard {
          Some(g) -> search_expression(g, aliases, member_name)
          None -> False
        }
      })

    glance.Fn(_, _, _, body) -> search_statements(body, aliases, member_name)

    glance.Tuple(_, elements) ->
      list.any(elements, fn(e) { search_expression(e, aliases, member_name) })

    glance.List(_, elements, rest) ->
      list.any(elements, fn(e) { search_expression(e, aliases, member_name) })
      || case rest {
        Some(r) -> search_expression(r, aliases, member_name)
        None -> False
      }

    glance.BinaryOperator(_, _, left, right) ->
      search_expression(left, aliases, member_name)
      || search_expression(right, aliases, member_name)

    glance.NegateInt(_, inner) | glance.NegateBool(_, inner) ->
      search_expression(inner, aliases, member_name)

    glance.Echo(_, Some(inner), _) ->
      search_expression(inner, aliases, member_name)

    glance.Panic(_, Some(inner)) | glance.Todo(_, Some(inner)) ->
      search_expression(inner, aliases, member_name)

    glance.TupleIndex(_, tuple, _) ->
      search_expression(tuple, aliases, member_name)

    glance.FnCapture(_, _, function, args_before, args_after) ->
      search_expression(function, aliases, member_name)
      || list.any(args_before, fn(field) {
        search_field_expr(field, aliases, member_name)
      })
      || list.any(args_after, fn(field) {
        search_field_expr(field, aliases, member_name)
      })

    glance.BitString(_, segments) ->
      list.any(segments, fn(seg) {
        search_expression(seg.0, aliases, member_name)
      })

    glance.RecordUpdate(_, None, _, record, fields) ->
      search_expression(record, aliases, member_name)
      || list.any(fields, fn(field) {
        case field.item {
          Some(e) -> search_expression(e, aliases, member_name)
          None -> False
        }
      })

    // Leaf nodes
    glance.Int(_, _)
    | glance.Float(_, _)
    | glance.String(_, _)
    | glance.Variable(_, _)
    | glance.Panic(_, None)
    | glance.Todo(_, None)
    | glance.Echo(_, None, _) -> False
  }
}

fn search_field_expr(
  field: glance.Field(Expression),
  aliases: List(String),
  member_name: String,
) -> Bool {
  case field {
    glance.LabelledField(_, _, item) ->
      search_expression(item, aliases, member_name)
    glance.UnlabelledField(item) ->
      search_expression(item, aliases, member_name)
    glance.ShorthandField(_, _) -> False
  }
}

fn search_pattern(
  pattern: Pattern,
  aliases: List(String),
  member_name: String,
) -> Bool {
  case pattern {
    glance.PatternVariant(_, Some(module_name), constructor, arguments, _) ->
      { constructor == member_name && list.contains(aliases, module_name) }
      || list.any(arguments, fn(field) {
        case field {
          glance.LabelledField(_, _, item) ->
            search_pattern(item, aliases, member_name)
          glance.UnlabelledField(item) ->
            search_pattern(item, aliases, member_name)
          glance.ShorthandField(_, _) -> False
        }
      })

    glance.PatternVariant(_, None, _, arguments, _) ->
      list.any(arguments, fn(field) {
        case field {
          glance.LabelledField(_, _, item) ->
            search_pattern(item, aliases, member_name)
          glance.UnlabelledField(item) ->
            search_pattern(item, aliases, member_name)
          glance.ShorthandField(_, _) -> False
        }
      })

    glance.PatternTuple(_, elements) ->
      list.any(elements, fn(p) { search_pattern(p, aliases, member_name) })

    glance.PatternList(_, elements, tail) ->
      list.any(elements, fn(p) { search_pattern(p, aliases, member_name) })
      || case tail {
        Some(t) -> search_pattern(t, aliases, member_name)
        None -> False
      }

    glance.PatternAssignment(_, inner, _) ->
      search_pattern(inner, aliases, member_name)

    glance.PatternBitString(_, segments) ->
      list.any(segments, fn(seg) { search_pattern(seg.0, aliases, member_name) })

    // Leaf patterns
    glance.PatternInt(_, _)
    | glance.PatternFloat(_, _)
    | glance.PatternString(_, _)
    | glance.PatternDiscard(_, _)
    | glance.PatternVariable(_, _)
    | glance.PatternConcatenate(_, _, _, _) -> False
  }
}

fn search_type(type_: Type, aliases: List(String), member_name: String) -> Bool {
  case type_ {
    glance.NamedType(_, name, Some(module_name), parameters) ->
      { name == member_name && list.contains(aliases, module_name) }
      || list.any(parameters, fn(p) { search_type(p, aliases, member_name) })

    glance.NamedType(_, _, None, parameters) ->
      list.any(parameters, fn(p) { search_type(p, aliases, member_name) })

    glance.TupleType(_, elements) ->
      list.any(elements, fn(t) { search_type(t, aliases, member_name) })

    glance.FunctionType(_, parameters, return) ->
      list.any(parameters, fn(t) { search_type(t, aliases, member_name) })
      || search_type(return, aliases, member_name)

    glance.VariableType(_, _) | glance.HoleType(_, _) -> False
  }
}

// --- Orchestration ---

pub fn check_unused_exports(
  src_files: List(#(String, String, String)),
  test_files: List(#(String, String, String)),
  severity: rule.Severity,
) -> List(rule.LintResult) {
  // Parse all files
  let parsed_src =
    list.filter_map(src_files, fn(f) {
      let #(path, module_path, source) = f
      case glance.module(source) {
        Ok(module) -> Ok(#(path, module_path, module))
        Error(_) -> Error(Nil)
      }
    })
  let parsed_test =
    list.filter_map(test_files, fn(f) {
      let #(path, module_path, source) = f
      case glance.module(source) {
        Ok(module) -> Ok(#(path, module_path, module))
        Error(_) -> Error(Nil)
      }
    })
  let all_consumers = list.append(parsed_src, parsed_test)

  // For each src file, collect pub definitions and check usage
  parsed_src
  |> list.flat_map(fn(src) {
    let #(file_path, module_path, module) = src
    let pub_defs = collect_pub_definitions(module)
    let other_files = list.filter(all_consumers, fn(f) { f.0 != file_path })

    pub_defs
    |> list.filter_map(fn(pub_def) {
      let is_used =
        list.any(other_files, fn(consumer) {
          let #(_, _, consumer_module) = consumer
          is_member_used_in(
            consumer_module,
            module_path,
            pub_def.name,
            pub_def.kind,
          )
        })
      case is_used {
        True -> Error(Nil)
        False ->
          Ok(rule.LintResult(
            rule: "unused_exports",
            severity: severity,
            file: file_path,
            location: pub_def.location,
            message: kind_label(pub_def.kind)
              <> " '"
              <> pub_def.name
              <> "' is never used by another module",
            details: "",
          ))
      }
    })
  })
}

fn kind_label(kind: PubKind) -> String {
  case kind {
    PubFunction -> "Public function"
    PubConstant -> "Public constant"
    PubCustomType -> "Public type"
    PubTypeAlias -> "Public type alias"
  }
}
