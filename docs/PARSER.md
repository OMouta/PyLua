# Parser

Parses tokens into a Python-like AST. Split across small modules for maintainability.

- Entry: `parser/init.luau` with `parse(tokens)` and `parseExpression(tokens)`
- Modules: `expressions.luau`, `statements.luau`, `postfix.luau`, `precedence.luau`, `errors.luau`

## Expressions supported

- Literals: numbers, strings, bytes (via lexer prefix), True/False/None
- Names, attribute access `obj.attr`, subscripts `seq[i]`
- Calls `func(a, b, ...)`
- Binary ops: + - * / % ** // << >> | ^ & @
- Unary ops: + - ~ not
- Comparisons: < <= == != > >=, `is`/`is not`, `in`/`not in`
- Collections: list, tuple, set, dict literals
- List comprehensions: `[expr for x in it if cond ...]`

## Statements supported

- Assign: simple and multiple targets (Name, attribute, subscript; tuple destructuring fully supported)
- AugAssign: `+=, -=, *=, /=, //=, %=, **=, <<=, >>=, &=, ^=, |=, @=`
- Expr statements: function calls, expressions
- Control flow: `if`/`elif`/`else`
- Loops: `while`, `for ... in ...` (+ optional `else:`)
  - For-loop targets support tuple destructuring: `for x, y in items:` or `for (x, y) in items:`
  - Nested tuple destructuring: `for (a, b), c in items:` works recursively
- Function definitions: `def name(args): ...`

## Notes

- Operator precedence matches Python
- Chained comparisons are parsed, but see compiler notes for current emission limits
- Source positions (`lineno`, `col_offset`) are set for error reporting and debugging
