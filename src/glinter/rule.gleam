import glance.{type Expression, type Module, type Span, type Statement}

pub type Severity {
  Error
  Warning
}

pub type LintResult {
  LintResult(
    rule: String,
    severity: Severity,
    file: String,
    location: Span,
    message: String,
  )
}

/// Pre-computed data from a single AST traversal.
/// Rules receive this instead of walking the AST themselves.
pub type ModuleData {
  ModuleData(
    module: Module,
    expressions: List(Expression),
    statements: List(Statement),
  )
}

pub type Rule {
  Rule(
    name: String,
    default_severity: Severity,
    check: fn(ModuleData, String) -> List(LintResult),
  )
}
