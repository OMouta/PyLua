# PyLua v0.3 Rewrite Plan

> **Complete rewrite of PyLua from scratch with proper Python syntax and core functionality**
> Check [LANGUAGE_IMPLEMENTATION.md](LANGUAGE_IMPLEMENTATION.md) for in-depth CPython internals research.

## Overview

This document outlines the complete rewrite of PyLua to create a proper Python interpreter in Luau, inspired by Lupa's API design but inverse (Python-in-Luau instead of Lua-in-Python).

**Python Version Support**: PyLua v0.3 targets Python 3.12 syntax and below. Supporting Python 3.13+ would add unnecessary complexity for an embedded language interpreter.

## Status Key

- [x] Complete
- [ ] Planned / Not started
- [-] Deferred (explicitly postponed)

## Current Issues with PyLua v0.2

- ❌ Primitive tokenizer with poor Python syntax support
- ❌ No proper Abstract Syntax Tree (AST) parsing
- ❌ Limited Python compliance and missing core features
- ❌ Brittle, tightly-coupled architecture
- ❌ Incomplete Python object model
- ❌ Poor error handling and debugging support

## Target Architecture

### Pipeline Design (Following CPython)

```txt
Python Source → Lexer → Parser → AST → Compiler → Bytecode → VM → Results
```

### Directory Structure

```txt
src/PyLua/
├── init.luau              # Main API (Lupa-inspired interface)
├── lexer.luau            # Python-compliant tokenization
├── parser.luau           # AST generation from tokens  
├── ast/                  # AST node definitions
│   ├── nodes.luau        # All AST node types
│   └── visitor.luau      # AST visitor pattern
├── compiler.luau         # AST → Bytecode compilation
├── bytecode/             # Bytecode system
│   ├── opcodes.luau      # Python-like opcodes
│   └── instructions.luau # Instruction definitions
├── vm/                   # Virtual Machine
│   ├── interpreter.luau  # Main execution loop
│   ├── frame.luau        # Execution frames
│   └── stack.luau        # Value stack management
├── objects/              # Python object system
│   ├── base.luau         # Base PyObject
│   ├── builtins.luau     # Built-in types
│   ├── collections.luau  # list, dict, tuple, set
│   └── functions.luau    # Function objects
└── builtins/             # Built-in functions
    ├── functions.luau    # print, len, type, etc.
    └── exceptions.luau   # Exception handling
```

## Implementation Phases

### Phase 1: Foundation

**Goal**: Establish core infrastructure

#### 1.1 Project Setup

- [x] Create new `src/PyLua/` directory structure
- [x] Set up basic module system and exports
- [x] Create comprehensive test framework
- [x] Set up documentation structure

#### 1.2 Lexer Implementation

- [x] **Token definitions**: All Python tokens (keywords, operators, literals)
- [x] **String handling**: Raw strings, f-strings, escape sequences
- [x] **Indentation parsing**: Python's whitespace significance
- [x] **Number parsing**: Integers, floats, scientific notation
- [x] **Comment handling**: Single-line and documentation strings
- [x] **Error reporting**: Line/column information for debugging

**Key Files**: `lexer.luau`, `tokens.luau`

#### 1.3 AST System Foundation

- [x] **Base AST node**: Common interface for all nodes
- [x] **Node types**: Module, Statement, Expression hierarchies
- [x] **Visitor pattern**: For AST traversal and manipulation
- [x] **Source location**: Track original source positions

**Key Files**: `ast/nodes.luau`, `ast/visitor.luau`

### Phase 2: Core Parser

**Goal**: Convert tokens to proper AST

#### 2.1 Expression Parser

- [x] **Literals**: Numbers, strings, booleans, None
- [x] **Variables**: Name resolution and binding
- [x] **Binary operations**: Arithmetic, comparison, logical
- [x] **Unary operations**: Negation, not, bitwise
- [x] **Operator precedence**: Correct Python precedence rules
- [x] **Parentheses**: Grouping and function calls

#### 2.2 Statement Parser

- [x] **Assignment**: Simple and multiple assignment
- [x] **Expression statements**: Function calls, method calls
- [x] **Control flow**: if/elif/else parsing
- [x] **Loops**: for and while loop parsing
- [x] **Function definitions**: def statement parsing

#### 2.3 Advanced Parsing

- [x] **Collections**: List, dict, tuple, set literals
- [x] **Indexing**: Subscript operations
- [x] **Attribute access**: Dot notation
- [x] **Function calls**: Arguments and keyword arguments

**Key Files**: `parser.luau`, `ast/nodes.luau`

#### 2.4 Parser Enhancements (Follow-ups)

Further refinement of parser toward fuller Python 3.12 compliance before compilation phase.

- [x] **Boolean operations**: Collapse chained `and` / `or` into `BoolOp` nodes (short-circuit semantics)
- [x] **Chained comparisons**: Support `a < b < c` producing single `Compare` with multiple ops/comparators
- [x] **Augmented assignment**: Parse `+=, -=, *=, /=, //=, %=, **=, <<=, >>=, &=, ^=, |=, @=` into `AugAssign`
- [x] **Starred expressions in literals**: `[ *a, *b ]`, `(*a, b)`, `{*a}` unpacking
- [x] **Dict unpacking**: `{**d1, **d2, 'k': v}` handling (keys = nil for unpack parts)
- [x] **Starred call arguments**: `func(*seq, **mapping)` argument unpacking
- [x] **Function parameters**: Parse full signature forms (pos-only `/`, `*` marker, defaults, `*args`, `**kwargs`, keyword-only)
- [x] **Assignment targets**: Allow attribute and subscript targets (`obj.attr =`, `seq[i] =`)
- [x] **Compound comparison keywords**: Properly distinguish `is not` and `not in`
- [-] **Error reporting**: Rich, recovery-friendly parse errors with expected token sets | Deferred (no structured recovery yet)

**Key Files**: `parser.luau`, `ast/nodes.luau`

#### 2.5 Parser Modularization & Maintenance

Goal: Reduce `parser.luau` size / complexity, improve readability, and prepare for future grammar extensions (comprehensions, lambdas, pattern matching if ever added) while keeping clear unit boundaries.

- [x] **File Decomposition**: Split monolithic `parser.luau` into submodules:
    `parser/init.luau` (public API + orchestration)
    `parser/expressions.luau` (expression grammar & precedence climbing)
    `parser/statements.luau` (simple + compound statements)
    `parser/postfix.luau` (attribute / subscript / call chaining & argument parsing)
    `parser/collections.luau` (list / tuple / set / dict + unpack forms)
    `parser/errors.luau` (diagnostics helpers, formatted expectation lists)
    `parser/precedence.luau` (central precedence & operator tables)
- [x] **Node Builders**: Introduce small constructor helpers (e.g. `makeName`, `makeBinOp`) to reduce inline table repetition.
- [x] **Context Handling**: Central function to transform Load -> Store contexts for assignment targets (supports attribute & subscript targets).
- [x] **Error Recovery**: Implement lightweight synchronization (skip until one of `NEWLINE`, `DEDENT`, `ENDMARKER`) to continue parsing after an error for multi-error reporting.
- [x] **Chained Comparison Unification**: Move comparison folding logic into dedicated helper for reuse.
- [x] **AugAssign Support**: Parse augmented assignment operators (links with Enhancements checklist) via a dispatch table.
- [x] **Argument Parser Upgrade**: Single function handling positional-only, normal, var-positional, keyword-only, var-keyword parameters + defaults mapping.
- [x] **Performance Profiling**: Add optional debug flag to collect token consumption counts & timing.
- [x] **Test Restructure**: Split `test_parser.luau` into `test_parser_expr.luau`, `test_parser_stmt.luau`, `test_parser_adv.luau` for targeted coverage.
- [x] **Grammar Doc Sync**: Add `internalDocs/GRAMMAR_NOTES.md` summarizing supported subset & deviations from CPython.
- [x] **Line/Column End Tracking**: Enhance to set `end_lineno` / `end_col_offset` for all new nodes consistently.
- [x] **String prefix acceptance**: Treat `u''` as `str` (no semantic difference in 3.x); ensure parser tolerates and normalizes.
- [x] **Bytes literal plumbing**: Recognize `b''` forms and route to `bytes` object creation once type exists (see Phase 3.2).

**Key Files (new)**: `src/PyLua/parser/*.luau`

Completion Criteria: Original `parser.luau` shrinks to thin façade (<150 lines), cyclomatic complexity per module reduced, tests green, and no regression in previously implemented features.

### Phase 3: Object System

**Goal**: Implement Python's object model

#### 3.1 Base Object System

- [x] **PyObject**: Base class with `__type`, `__value`, `__dict`
- [x] **Type system**: Runtime type checking and conversion
- [x] **Attribute access**: `__getattr__`, `__setattr__` mechanisms
- [x] **Method resolution**: Finding and calling methods

#### 3.2 Built-in Types

- [x] **Numbers**: int, float with proper arithmetic
- [x] **Strings**: str with methods and operations
- [x] **Booleans**: bool with truthiness rules
- [x] **None**: Python's null value
- [x] **Type objects**: Representing types themselves (placeholder minimal)
- [x] **Bytes**: `bytes` type and `b''` literals (basic operations and interop).

#### 3.3 Collections

- [x] **Lists**: Dynamic arrays with Python list methods
- [x] **Dictionaries**: Hash maps with Python dict interface
- [x] **Tuples**: Immutable sequences
- [x] **Sets**: Unique value collections
- [x] **Iterators**: Protocol for iteration

**Key Files**: `objects/base.luau`, `objects/builtins.luau`, `objects/collections.luau`

### Phase 4: Bytecode & Virtual Machine

**Goal**: Execute AST through bytecode

#### 4.1 Bytecode System

- [x] **Opcodes**: Python-like instruction set
  - LOAD_CONST, LOAD_FAST, STORE_FAST
  - BINARY_ADD, BINARY_SUBTRACT, etc.
  - CALL_FUNCTION, RETURN_VALUE
  - JUMP_FORWARD, POP_JUMP_IF_FALSE
- [x] **Code objects**: Bytecode containers with metadata
- [x] **Compilation**: AST → Bytecode transformation

#### 4.2 Virtual Machine

- [x] **Execution frames**: Function call contexts
- [x] **Value stack**: Operand stack for calculations
- [x] **Instruction dispatch**: Main execution loop
- [x] **Variable storage**: Local, global, and builtin scopes
- [x] **Function calls**: Parameter passing and return values

#### 4.3 Control Flow

- [x] **Conditionals**: if/else execution
- [ ] **elif chains**: Full support in parser and VM
- [x] **Loops**: for and while loop execution
- [x] **Break/continue**: Loop control statements
- [x] **Function returns**: Return value handling

**Key Files**: `compiler.luau`, `bytecode/opcodes.luau`, `vm/interpreter.luau`, `vm/frame.luau`, `vm/stack.luau`

### Phase 5: Built-ins & Advanced Features

**Goal**: Essential Python functionality

#### 5.1 Built-in Functions

- [ ] **print()**: Output with proper formatting
- [ ] **len()**: Length of collections
- [ ] **type()**: Runtime type inspection  
- [ ] **range()**: Number sequence generation
- [ ] **int(), float(), str(), bool()**: Type conversions
- [ ] **sum(), min(), max()**: Aggregate functions

#### 5.2 Advanced Language Features

- [ ] **List comprehensions**: [x for x in iterable]
- [ ] **Lambda functions**: Anonymous functions
- [ ] **Generators**: yield expressions and iteration
- [ ] **Exception handling**: Basic try/except (future)
- [ ] **f-strings**: Runtime expression interpolation and formatting (lexer already tokenizes prefixes; implement evaluation and formatting).
- [ ] **FloorDiv and MatMult**: Implement `//` and `@` operators end-to-end (lexer, parser, compiler, VM).

#### 5.3 Python-Luau Interop

- [ ] **Luau function calls**: Call Luau from Python
- [ ] **Object conversion**: Python ↔ Luau type mapping
- [ ] **Error translation**: Python exceptions ↔ Luau errors

**Key Files**: `builtins/functions.luau`, `builtins/exceptions.luau`

## API Design (Lupa-inspired)

### Target Usage

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
print(result) -- 15

-- Access globals
local globals = python:globals()
print(globals.x)  -- {1, 2, 3}

-- Pass Luau functions to Python
python:globals().lua_func = function(a, b) return a * b end
python:execute("result = lua_func(6, 7)")
```

## Design Principles

1. **Python 3.12 Compliance**: Follow Python 3.12 and below semantics as closely as possible
2. **Extensibility**: Clean module boundaries for future features
3. **Performance**: Efficient bytecode execution
4. **Memory Management**: Proper object lifecycle
5. **Error Handling**: Meaningful error messages with source location
6. **Lupa-like API**: Familiar interface for Python-Lua interop users

## Testing Strategy

### Unit Tests

- [ ] Lexer: Token generation from source
- [ ] Parser: AST generation from tokens
- [ ] Objects: Python object behavior
- [ ] VM: Bytecode execution
- [ ] Built-ins: Function behavior

### Integration Tests

- [ ] End-to-end: Python source → execution
- [ ] Interop: Python ↔ Luau communication
- [ ] Error handling: Proper error propagation

### Performance Tests

- [ ] Benchmarks: Execution speed comparisons
- [ ] Memory usage: Object lifecycle tracking

## Future Roadmap

### v3.1 - Classes & Modules

- [ ] Class definitions and inheritance
- [ ] Module system and imports
- [ ] Package structure

### v3.2 - Advanced Features

- [ ] Decorators
- [ ] Context managers
- [ ] Async/await (coroutines)

### v3.3 - Standard Library

- [ ] Core modules (math, string, etc.)
- [ ] File I/O operations
- [ ] JSON handling

### v3.4 - Optimization

- [ ] Bytecode optimization
- [ ] JIT compilation possibilities
- [ ] Memory optimizations

## Success Criteria

- ✅ **Correctness**: Python code executes with proper semantics
- ✅ **Completeness**: Core Python features are implemented
- ✅ **Performance**: Reasonable execution speed for interpreted code
- ✅ **Usability**: Clean, Lupa-inspired API
- ✅ **Maintainability**: Modular, well-documented codebase
- ✅ **Extensibility**: Easy to add new Python features

## Getting Started

1. Review this plan and the current PyLua codebase in `old/`
2. Set up the new directory structure in `src/`
3. Use test-driven development throughout
4. Refer to CPython source and Python language reference for accuracy

---

*This rewrite represents a complete architectural overhaul to create a production-quality Python interpreter in Luau.*
