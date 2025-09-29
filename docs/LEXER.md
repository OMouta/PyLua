# Lexer

Tokenizes Python code while preserving Python’s indentation model and string literal forms.

## Highlights

- INDENT/DEDENT via a stack to represent Python blocks
- NEWLINE tokens for statement boundaries; ENDMARKER at EOF
- Numbers: decimal, floats, scientific; 0b/0o/0x prefixes
- Strings: single, double, triple quotes; prefixes r/f/u/b and combinations
- Comments: skipped to end-of-line
- Two-char operators: == != <= >= ** // << >>
- Single-char operators and punctuation matched to CPython token names

## Implementation notes

- File: `src/PyLua/lexer.luau`
- String tokens carry extras:
  - stringPrefix: e.g. "r", "f", "u", "b" (lowercased; combinations preserved)
  - isTriple: boolean
  - stringContent: raw inner content (escapes kept if not raw)
- Indentation:
  - Leading spaces count; tabs treated as width 8 (like CPython tokenization)
  - Emits INDENT/DEDENT; balances remaining DEDENTs at EOF
- NEWLINE tokens include the line/col where the newline occurred

Error modes:

- Unterminated string → ERRORTOKEN
- Inconsistent indentation → ERRORTOKEN("IndentationError")
