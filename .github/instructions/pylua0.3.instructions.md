---
applyTo: '**'
---

# GitHub Copilot Instructions for PyLua v0.3 Rewrite

## Project Overview

You are working on **PyLua v0.3**, a complete rewrite of a Python interpreter implementation in Luau for Roblox. The goal is to create a proper Python interpreter that runs inside Roblox, with a Lupa-inspired API (inverse - Python-in-Luau instead of Lua-in-Python).

**Python Version Support**: PyLua targets Python 3.12 syntax and below. Supporting Python 3.13+ would add unnecessary complexity for an embedded language interpreter.

## Current Context

- **Old Implementation**: Located in `old/PyLua/` - this is poorly written, basic tokenizer, no proper AST
- **New Implementation**: Will be in `src/PyLua/` - complete rewrite with proper architecture
- **Target**: Production-quality Python interpreter following CPython design principles
- **API Style**: Lupa-inspired but inverse (Python running in Luau)

## Luau Runtime

We are using lune, a luau runtime for executing Luau code instead of the luau runtime. Use lune run <file> to execute a Luau file.

## Architecture Overview

### Pipeline Design (Following CPython)
```
Python Source → Lexer → Parser → AST → Compiler → Bytecode → VM → Results
```

### Key Components
1. **Lexer** (`lexer.luau`) - Python-compliant tokenization
2. **Parser** (`parser.luau`) - AST generation from tokens
3. **AST System** (`ast/`) - Python AST node definitions and visitor pattern
4. **Compiler** (`compiler.luau`) - AST to bytecode compilation
5. **Virtual Machine** (`vm/`) - Bytecode execution with frames and stack
6. **Object System** (`objects/`) - Python object model implementation
7. **Built-ins** (`builtins/`) - Python built-in functions and types

## Code Style & Standards

### Luau Conventions
- Use proper Luau type annotations: `function foo(x: number): string`
- Export types: `export type PyObject = { ... }`
- Use `local` for module-private functions
- Return module table at end: `return ModuleName`

### Python Compliance
- Follow Python 3.12 and below semantics exactly where possible
- Use Python-like naming for opcodes (LOAD_CONST, STORE_FAST, etc.)
- Implement Python operator precedence correctly
- Handle Python's dynamic typing properly

### Error Handling
- Always include source location information in errors
- Provide meaningful error messages that help users
- Use consistent error formats across modules

## Current Implementation Phase

**Phase 1: Foundation** - We are currently working on:
1. Setting up the new directory structure in `src/PyLua/`
2. Implementing the lexer with proper Python tokenization
3. Creating the AST system foundation

## Key Implementation Guidelines

### 1. Lexer Implementation (`lexer.luau`)
- Handle all Python tokens: keywords, operators, literals, identifiers
- Proper string parsing: raw strings, f-strings, escape sequences
- Python's indentation-based syntax (INDENT/DEDENT tokens)
- Number parsing: integers, floats, scientific notation
- Comments and newlines
- Line/column tracking for error reporting

### 2. AST System (`ast/nodes.luau`)
```luau
-- Base AST node
export type ASTNode = {
    type: string,           -- Node type identifier
    lineno: number,         -- Source line number
    col_offset: number,     -- Column offset
}

-- Expression nodes
export type Expr = ASTNode & {
    -- Common expression interface
}

-- Statement nodes  
export type Stmt = ASTNode & {
    -- Common statement interface
}
```

### 3. Python Object Model (`objects/base.luau`)
```luau
-- Base Python object
export type PyObject = {
    __type: string,         -- Python type name
    __value: any,          -- Actual Luau value
    __dict: {[string]: PyObject}?, -- Object attributes
}
```

### 4. Virtual Machine Architecture
- Stack-based execution like CPython
- Execution frames for function calls
- Proper scope handling (local, global, builtin)
- Exception handling preparation

## Testing Requirements

### Test Structure
- Unit tests for each component
- Integration tests for end-to-end functionality
- Performance benchmarks
- Python compliance tests

### Test Examples
```luau
-- Lexer tests
local tokens = lexer.tokenize("x = 42")
assert(tokens[1].type == "NAME")
assert(tokens[2].type == "ASSIGN")
assert(tokens[3].type == "NUMBER")

-- Parser tests
local ast = parser.parse(tokens)
assert(ast.type == "Module")
assert(#ast.body == 1)
assert(ast.body[1].type == "Assign")
```

## API Design Target

```lua
local PyLua = require('src.PyLua')

-- Create runtime instance
local python = PyLua.new({
    debug = false,
    timeout = 5.0
})

-- Execute Python code
python:execute([[
    x = [1, 2, 3]
    y = {'name': 'test', 'value': 42}
    print(f"List: {x}, Dict: {y}")
]])

-- Evaluate expressions
local result = python:eval("sum([1, 2, 3, 4, 5])")

-- Access globals
local globals = python:globals()
```

## Common Patterns

### Module Structure
```luau
-- Module header
local ModuleName = {}

-- Dependencies
local types = require('path.to.types')
local utils = require('path.to.utils')

-- Type definitions
export type ModuleType = {
    field: string
}

-- Private functions
local function privateHelper()
    -- implementation
end

-- Public API
function ModuleName.publicFunction(param: string): boolean
    -- implementation
end

-- Module export
return ModuleName
```

### Error Handling
```luau
local function parseExpression(tokens: {Token}, pos: number): (Expr?, string?)
    if not tokens[pos] then
        return nil, "Unexpected end of input"
    end
    
    -- parsing logic
    
    return expr, nil -- success
end
```

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
