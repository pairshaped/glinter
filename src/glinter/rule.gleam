import glance.{
  type Expression, type Function, type Module, type Span, type Statement,
}
import gleam/option.{type Option}

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

pub type Rule {
  Rule(
    name: String,
    default_severity: Severity,
    check_expression: Option(fn(Expression) -> List(LintResult)),
    check_statement: Option(fn(Statement) -> List(LintResult)),
    check_function: Option(fn(Function) -> List(LintResult)),
    check_module: Option(fn(Module) -> List(LintResult)),
  )
}
