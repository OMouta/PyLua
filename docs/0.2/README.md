# PyLua - Python Interpreter in Luau for Roblox

A Python interpreter implementation written in Luau that runs inside Roblox. PyLua 0.2 compiles Python code to bytecode for efficient execution, featuring comprehensive support for Python language features.

## Quick Start

### Basic Usage

```lua
local python = require('path.to.PyLua.python')

-- Simple one-line execution
python.execute('print("Hello, PyLua!")')
```

### Compile Once, Execute Multiple Times

For better performance when running the same code repeatedly:

```lua
local python = require('path.to.PyLua.python')

-- Compile Python code to bytecode
local bytecode, error = python.compile([[
x = 10
y = 20
result = x + y
print("Result:", result)
]])

if error then
    print("Compilation error:", error)
    return
end

-- Execute the bytecode multiple times
for i = 1, 5 do
    print("Execution", i)
    local success, variables = python.runBytecode(bytecode)
    if success then
        print("Variables:", variables)
    end
end
```

### Advanced Example with Data Structures

```lua
local python = require('path.to.PyLua.python')

local code = [[
# Create and manipulate Python data structures
students = [
    {"name": "Alice", "grade": 85},
    {"name": "Bob", "grade": 92},
    {"name": "Charlie", "grade": 78}
]

print("Student grades:")
total = 0
count = 0

for student in students:
    name = student["name"]
    grade = student["grade"]
    print(name, ":", grade)
    
    total = total + grade
    count = count + 1

average = total / count
print("Class average:", average)

if average >= 80:
    print("Great class performance!")
else:
    print("Room for improvement")
]]

-- Compile and execute
local bytecode, compileError = python.compile(code)
if compileError then
    print("Compilation failed:", compileError)
else
    local success, variables = python.runBytecode(bytecode)
    if not success then
        print("Runtime error:", variables)
    end
end
```

## API Reference

### `python.execute(code)`

Compiles and immediately executes Python code.

- **Parameters**: `code` (string) - Python source code
- **Returns**: `success` (boolean), `result` (any) - Execution result or error message

### `python.compile(code)`

Compiles Python source code to bytecode for later execution.

- **Parameters**: `code` (string) - Python source code
- **Returns**: `bytecode` (table), `error` (string|nil) - Compiled bytecode or error message

### `python.runBytecode(bytecode, options?)`

Executes pre-compiled bytecode.

- **Parameters:**
  - `bytecode` (table) - Compiled bytecode from `python.compile()`
  - `options` (table, optional) - Execution options
    - `debug` (boolean) - Enable debug output
- **Returns**: `success` (boolean), `variables` (table) - Success status and variable state

## 🔧 Bytecode Management

### Why Use Bytecode?

Bytecode compilation provides several advantages:

1. **Performance**: Compile once, execute many times without re-parsing
2. **Validation**: Catch syntax errors at compile time
3. **Inspection**: Examine bytecode structure for debugging
4. **Caching**: Store compiled bytecode for future use

### Bytecode Structure

```lua
local bytecode = {
    constants = {}, -- Constant values (numbers, strings, etc.)
    names = {},     -- Variable and function names
    code = {},      -- Bytecode instructions
    sourceLines = {} -- Original source lines for error reporting
}
```

### Debug Mode

Enable debug mode to see detailed execution information:

```lua
local python = require('path.to.PyLua.python')

local bytecode = python.compile('x = 42\nprint("x =", x)')
python.runBytecode(bytecode, {debug = true})
```

Debug output includes:

- Stack operations (PUSH/POP)
- Variable assignments
- Function calls
- Instruction execution flow

## Supported Python Features

### Data Types

- **Numbers**: Integers and floats
- **Strings**: Text with proper escaping
- **Booleans**: `True`, `False`
- **None**: Python's null value

### Data Structures

- **Lists**: `[1, 2, 3]` with indexing and `len()`
- **Dictionaries**: `{"key": "value"}` with key access
- **Tuples**: `(1, 2, 3)` immutable sequences
- **Sets**: `{1, 2, 3}` unique value collections

### Control Flow

- **Conditionals**: `if`, `elif`, `else` with nesting
- **For Loops**: `for item in iterable:` over lists, ranges, etc.
- **While Loops**: `while condition:` with proper termination

### Built-in Functions

- `print(*args)` - Output values
- `len(obj)` - Get length of collections
- `type(obj)` - Get object type
- `range(start, stop, step)` - Generate number sequences
- `int(value)`, `float(value)`, `str(value)`, `bool(value)` - Type conversion

### Operators

- **Arithmetic**: `+`, `-`, `*`, `/`, `%`, `**`
- **Comparison**: `==`, `!=`, `<`, `<=`, `>`, `>=`
- **Assignment**: `=`

## Architecture

PyLua 0.2 uses a three-phase architecture:

1. **Compiler** (`compiler/compiler.luau`): Parses Python source and generates bytecode
2. **Virtual Machine** (`vm/bytecode_executor.luau`): Executes bytecode instructions
3. **Core Libraries** (`core/`): Built-in functions and Python object implementations

```txt
Python Source Code
       ↓
   [Tokenizer]
       ↓
   [Compiler] → Bytecode
       ↓
  [VM Executor] → Results
```

## Limitations

Current limitations (may be addressed in future versions):

- No custom function definitions (`def`)
- No classes or inheritance
- Limited exception handling
- No module imports
- No list comprehensions

## License

This repository is under the [`MIT license`](./LICENSE).
