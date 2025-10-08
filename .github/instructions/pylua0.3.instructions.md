---
applyTo: '**'
---

# GitHub Copilot Instructions for PyLua v0.3 Rewrite

## Project Overview

PyLua is a **Python 3.12-and-below interpreter implemented in Luau**, designed to run inside Roblox and other Luau runtimes. It follows CPython's architecture with a full pipeline: **Lexer → Parser → AST → Compiler → Bytecode → VM**.

**Critical**: This is v0.3, a complete rewrite. Ignore the `old/PyLua/` directory entirely - it's poorly architected and not representative of current patterns.

## Execution Commands

```powershell
# Run tests (primary development workflow)
lute tests/run_tests.luau

# Run a specific example
lute docs/examples/hello_world.luau

# Build Roblox model (rarely needed during development)
jelly build
# or: rojo build default.project.json --output build/pylua.rbxm

# Format code
stylua src
```

**Key**: Use `lute` (not `luau`) - it's the Luau runtime we target. See `rokit.toml` for toolchain versions.

## Architecture: The CPython-Inspired Pipeline

### Phase Flow
```
Python Source → Lexer → Parser → AST → Compiler → Bytecode → VM → Result
```

### Directory Map
- **`src/PyLua/init.luau`**: Public API (`Runtime.new()`, `execute()`, `eval()`, `globals()`)
- **`lexer.luau`** + **`tokens.luau`**: Tokenization with Python INDENT/DEDENT handling
- **`parser/`**: Modular parser split across `expressions.luau`, `statements.luau`, `postfix.luau`, `precedence.luau`
- **`ast/`**: AST node definitions (`nodes.luau`) and visitor pattern (`visitor.luau`)
- **`compiler.luau`**: Emits bytecode from AST (CPython-style opcodes like `LOAD_CONST`, `STORE_NAME`)
- **`bytecode/`**: Instruction definitions and opcode constants
- **`vm/`**: Stack-based VM with frames (`frame.luau`), stack management (`stack.luau`), and interpreter loop (`interpreter.luau`)
- **`objects/`**: Python object model - `base.luau` defines `PyObject` type and type registry; `collections.luau` implements list/dict/tuple/set
- **`builtins/`**: Built-in functions (`print`, `len`, `range`, etc.) and exception types

### Critical Type: PyObject
```luau
export type PyObject = {
    __type: string,           -- Python type name ("int", "str", "list", etc.)
    __value: any,            -- Underlying Luau value
    __dict: {[string]: PyObject}?,  -- Instance attributes
    __typeobj: PyType,       -- Reference to type descriptor
}
```

All Python values flow through the system as `PyObject`. Use `Base.ensurePyObject()` to wrap Luau values and `Base.toLuau()` to unwrap.

## Code Conventions

### Luau Style
- **Type annotations mandatory**: `function foo(x: number): string`
- **Export types**: `export type MyType = { ... }`
- **Module structure**: 
  ```luau
  local Module = {}
  -- ... implementation ...
  return Module
  ```
- **Private functions**: Use `local function` for module-internal helpers
- **Require paths**: Use `@self` alias for internal imports (e.g., `require("@self/lexer")`)

### Python Compliance
- **Target Python 3.12 and below** - supporting 3.13+ is explicitly out of scope
- **Match CPython semantics exactly** where possible (operator precedence, control flow, object model)
- **Opcode names**: Use CPython conventions (`LOAD_CONST`, `BINARY_ADD`, `COMPARE_OP`)
- **Error messages**: Include source position (`lineno`, `col_offset`) in all error reporting

## Testing Framework

Tests live in `tests/suites/`. The custom framework in `tests/framework.luau` provides:

```luau
-- Test structure
TestFramework.suite("SuiteName", function(test)
    test("test description", function(assert)
        assert.equal(actual, expected)
        assert.isTrue(condition)
        assert.throws(function() ... end, "ErrorPattern")
    end)
end)
```

**Run all tests**: `lute tests/run_tests.luau`  
**Coverage**: Lexer, parser, AST, objects, builtins, bytecode, VM, control flow, functions

## Parser Architecture (Multi-Module)

The parser is **split across files** to manage complexity:

- **`parser/init.luau`**: Entry point with `parse()` and `parseExpression()`, manages parser state
- **`parser/expressions.luau`**: Expression parsing (literals, names, operators, comprehensions)
- **`parser/statements.luau`**: Statement parsing (assign, if/while/for, function defs)
- **`parser/postfix.luau`**: Postfix operations (attribute access, subscripts, calls)
- **`parser/precedence.luau`**: Operator precedence table (matches Python's)

**Pattern**: Parser state is passed between modules. Each module exports functions that consume tokens and return AST nodes.

## Indentation Handling (Python's Killer Feature)

Python's significant whitespace is handled in the **lexer**:
- **INDENT tokens**: Emitted when indentation increases
- **DEDENT tokens**: Emitted when indentation decreases (can emit multiple in one logical newline)
- **Stack-based tracking**: Maintains indentation level stack, balances at EOF
- **Tab handling**: Tabs count as width 8 (CPython behavior)

Example: `if x:\n    y = 1` produces tokens: `NAME IF NAME COLON NEWLINE INDENT NAME ASSIGN NUMBER NEWLINE DEDENT ENDMARKER`

## Bytecode Execution Model

The VM is **stack-based** like CPython:
- **Frames**: Each function call creates a frame (`vm/frame.luau`) with its own locals and stack
- **Stack operations**: Values push/pop during expression evaluation
- **Instruction format**: `{ opcode: string, arg?: number, lineno?: number }`
- **Key opcodes**: `LOAD_CONST`, `LOAD_NAME`, `STORE_NAME`, `BINARY_ADD`, `COMPARE_OP`, `POP_JUMP_IF_FALSE`, `FOR_ITER`, `UNPACK_SEQUENCE`

**Tuple unpacking example**:
```python
x, y = (1, 2)
```
Bytecode: `LOAD_CONST(tuple) → UNPACK_SEQUENCE(2) → STORE_NAME(y) → STORE_NAME(x)`  
(Right-to-left store order because stack is LIFO)

## Interop: Luau ↔ Python Globals

The **primary interop mechanism** is `globals()`:

```lua
local py = PyLua.new()
py:setGlobal("luau_value", 42)
py:execute("result = luau_value * 2")
print(py:getGlobal("result"))  -- 84
```

**Current limitations** (v0.3.0-dev):
- Passing Luau functions to Python is partially implemented
- Two-way callable binding is planned but not fully functional

See `docs/INTEROP.md` for planned full two-way binding features.

## Common Gotchas

1. **Don't reference old implementation**: Code in `old/PyLua/` is legacy and should be ignored
2. **Module require paths**: Use `@self` for internal imports, not relative paths
3. **Type exports**: Always `export type` for types used across modules
4. **Parser state**: Parser functions mutate state - pass the same state object through the parsing chain
5. **PyObject wrapping**: Raw Luau values must be wrapped with `Base.ensurePyObject()` before VM operations
6. **Error handling**: Always include line/column info from tokens when raising parse errors

## Development Workflow

**Typical change flow**:
1. Modify source in `src/PyLua/`
2. Add/update tests in `tests/suites/test_*.luau`
3. Run `lute tests/run_tests.luau` to validate
4. Format with `stylua src` before committing

**Adding new Python syntax**:
1. Add tokens to `tokens.luau` if needed
2. Update lexer in `lexer.luau` for new tokens
3. Add AST nodes to `ast/nodes.luau`
4. Implement parser logic in `parser/expressions.luau` or `parser/statements.luau`
5. Add compiler emission in `compiler.luau`
6. Implement VM behavior in `vm/interpreter.luau`
7. Write comprehensive tests

## Documentation Structure

- **`docs/README.md`**: Documentation index
- **`docs/ARCHITECTURE.md`**: High-level pipeline overview
- **`docs/LEXER.md`**, **`docs/PARSER.md`**, **`docs/COMPILER.md`**, **`docs/VM.md`**: Deep-dives on each pipeline stage
- **`docs/OBJECTS.md`**: Python object model implementation details
- **`docs/BYTECODE.md`**: Instruction set reference
- **`docs/examples/`**: Working code samples
- **`internalDocs/REWRITE_PLAN.md`**: Implementation checklist and phase tracking

## Quick Reference: Key Files

| When you need to... | Look at... |
|---------------------|------------|
| Understand the public API | `src/PyLua/init.luau` |
| Add a new token type | `src/PyLua/tokens.luau` |
| Parse a new expression form | `src/PyLua/parser/expressions.luau` |
| Add a new statement type | `src/PyLua/parser/statements.luau` |
| Emit new bytecode | `src/PyLua/compiler.luau` |
| Add a VM instruction | `src/PyLua/vm/interpreter.luau` |
| Implement Python built-in type | `src/PyLua/objects/builtins.luau` |
| Add built-in function | `src/PyLua/builtins/functions.luau` |
| Write tests | `tests/suites/test_*.luau` |


## What NOT to do

1. **Don't copy from old implementation** - it's fundamentally flawed
2. **Don't oversimplify parsing** - Python syntax is complex, handle it properly
3. **Don't skip error handling** - always provide meaningful error messages
4. **Don't ignore Python semantics** - follow Python behavior exactly
5. **Don't create tightly coupled modules** - maintain clean interfaces

## Current Priority Tasks

1. **Lexer**: Implement comprehensive Python tokenization
2. **AST Nodes**: Define all Python AST node types
3. **Parser**: Basic expression and statement parsing
4. **Object System**: Python object model foundation
5. **Tests**: Comprehensive test coverage for each component

## References

- Python 3.12 Language Reference: https://docs.python.org/3.12/reference/
- CPython 3.12 source code for implementation details
- Lupa documentation for API inspiration
- Python AST module documentation for node types

Remember: This is a complete rewrite focusing on correctness, maintainability, and Python 3.12 compliance. Take time to get the architecture right from the start.
