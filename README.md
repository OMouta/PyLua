# PyLua - Python Interpreter in Luau for Roblox

A modular Python interpreter implementation written in Luau that runs inside Roblox. PyLua allows you to execute Python-like code within the Roblox environment, featuring a clean modular architecture and support for core Python language features.

## 🚀 Features

### ✅ Implemented

- **Basic Operations**: Variable assignment, print statements, string/number literals
- **Mathematical Expressions**: Arithmetic operations with proper operator precedence (`+`, `-`, `*`, `/`)
- **Control Flow**:
  - `if`/`elif`/`else` conditional statements with Python-style truthiness
  - `for` loops with `range()` function (1-3 arguments) and string iteration
  - `while` loops with condition evaluation
  - **Nested loops and conditionals** - Full support for arbitrarily deep nesting
- **Built-in Functions**:
  - `print()` - Output with multiple arguments
  - `len()` - Get length of strings and tables
  - `str()` - Convert values to strings
  - `int()` - Convert values to integers
  - `float()` - Convert values to floating point numbers
  - `bool()` - Convert values to booleans with Python truthiness
  - `type()` - Get type of values
  - `range()` - Generate number sequences (supports 1-3 arguments like Python)
  - `min()` - Find minimum value from arguments or iterable
  - `max()` - Find maximum value from arguments or iterable
  - `sum()` - Sum all values in an iterable
  - `abs()` - Get absolute value of a number
  - `round()` - Round numbers to specified decimal places
  - `pow()` - Raise a number to a power (with optional modulo)
- **Comments**: Python-style `#` comments are supported
- **Variable Scope**: Proper variable scoping in nested control structures

### 🔄 In Development

- Function definitions (`def`)
- Lists and dictionaries
- More built-in functions
- Error handling and exceptions
- Import system

## 🏗️ Architecture

PyLua uses a modular architecture with clear separation of concerns:

```txt
src/server/PyLua/
├── python.lua      # Main interpreter and execution engine
├── tokenizer.lua   # Lexical analysis and tokenization
├── parser.lua      # Syntax analysis and AST generation
├── evaluator.lua   # Expression evaluation and statement execution
├── builtins.lua    # Built-in functions (print, len, str, etc.)
├── variables.lua   # Variable storage and scope management
└── controlflow.lua # Control flow execution (if, for, while)
```

## 📖 Usage

### Basic Example

```lua
local Python = require('./PyLua/python')

Python.execute([[
# Variables and basic operations
message = "Hello from PyLua!"
length = len(message)
print("Message:", message)
print("Length:", length)

# Conditional statements
score = 85
if score >= 90:
    print("Grade: A")
elif score >= 80:
    print("Grade: B")
else:
    print("Grade: C")

# Loops
print("Counting:")
for i in range(5):
    print("Count:", i)

# Nested loops
print("Multiplication table:")
for i in range(1, 4):
    for j in range(1, 4):
        result = i * j
        print(i, "x", j, "=", result)
]])
```

## 🔧 Supported Python Syntax

### Variables and Assignment

```python
name = "PyLua"
age = 25
pi = 3.14159
```

### Mathematical Operations

```python
result = (5 + 3) * 2
area = length * width
total = sum + tax
```

### Control Flow

#### Conditionals

```python
if condition:
    # do something
elif other_condition:
    # do something else
else:
    # default case
```

#### For Loops

```python
# Range with stop
for i in range(5):
    print(i)  # 0, 1, 2, 3, 4

# Range with start and stop
for i in range(2, 8):
    print(i)  # 2, 3, 4, 5, 6, 7

# Range with start, stop, and step
for i in range(0, 10, 2):
    print(i)  # 0, 2, 4, 6, 8

# String iteration
for letter in "Hello":
    print(letter)  # H, e, l, l, o
```

#### While Loops

```python
count = 0
while count < 5:
    print(count)
    count = count + 1
```

#### Nested Structures

```python
for i in range(3):
    for j in range(3):
        if i == j:
            print("Diagonal:", i, j)
        else:
            print("Off-diagonal:", i, j)
```

### Built-in Functions

```python
print("Hello", "World", 123)  # Multiple arguments
length = len("PyLua")         # String length
number = int("42")            # Convert to integer
decimal = float("3.14")       # Convert to float
truth = bool(1)               # Convert to boolean
text = str(123)               # Convert to string
data_type = type("hello")     # Get type
numbers = range(1, 10, 2)     # Generate range: [1, 3, 5, 7, 9]

# Math functions
total = sum([1, 2, 3, 4, 5])  # Sum: 15
minimum = min(1, 2, 3)        # Min: 1
maximum = max([1, 2, 3])      # Max: 3
absolute = abs(-5)            # Absolute: 5
rounded = round(3.14159, 2)   # Round: 3.14
power = pow(2, 3)             # Power: 8
```

### Comments

```python
# This is a comment
x = 5  # This is also a comment
```

## 🛠️ Development

### Project Structure

The project uses Rojo for syncing with Roblox Studio. The main interpreter is located in `src/server/PyLua/` with the test file at `src/server/server.server.luau`.

### Testing

Run the test file in Roblox Studio or use the Luau CLI:

```bash
luau src/server/server.server.luau
```

### Key Design Decisions

1. **Modular Architecture**: Each component has a single responsibility
2. **Recursive Parsing**: Supports arbitrarily deep nesting of control structures
3. **Token-based Processing**: Clean separation between lexical and syntactic analysis
4. **Scope Management**: Proper variable scoping in nested contexts
5. **Luau Compatibility**: Written in idiomatic Luau with proper type handling

## 🎯 Roadmap

### Short Term

- [ ] Function definitions and calls
- [x] ~~List data type and operations ~~ ✅ **Completed**
- [ ] Dictionary data type and operations
- [x] ~~More built-in functions (min, max, sum, etc.)~~ ✅ **Completed**

### Medium Term

- [ ] Exception handling (try/except)
- [ ] File I/O operations
- [ ] Module system and imports
- [ ] List comprehensions

### Long Term

- [ ] Class definitions and objects
- [ ] Advanced data structures
- [ ] Standard library implementation
- [ ] Performance optimizations

## 🤝 Contributing

PyLua is designed to be extensible. To add new features:

1. **Built-in Functions**: Add to `builtins.lua`
2. **Syntax Features**: Update `tokenizer.lua` and `parser.lua`
3. **Control Structures**: Extend `controlflow.lua`
4. **Expression Types**: Modify `evaluator.lua`

## 📝 License

Just dont say its yours, do whatever its under the MIT license (I chose it randomly)
