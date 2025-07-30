# PyLua - Embedded Python Interpreter for Luau

> **⚠️ Documentation Notice**: This documentation is for PyLua v0.3 with the new Lupa-inspired API. For v0.2 documentation, see `README_v0.2.md`.

A Python interpreter implementation written in Luau that runs inside Roblox. PyLua enables games to safely sandbox Python code and provide powerful modding interfaces for users. Execute Python code directly or compile to bytecode for efficient repeated execution.

## ✨ Features

- 🛡️ **Safe Sandboxing**: Execute Python code safely within controlled environments
- 🎮 **Game Modding Interface**: Provide players with Python scripting capabilities
- 🚀 **Bytecode Compilation**: Compile Python code once, execute multiple times
- 🐍 **Python Syntax**: Comprehensive support for Python variables, operators, control flow, and data structures
- 📦 **Data Structures**: Lists, dictionaries, tuples, sets with proper Python semantics
- 🔄 **Control Flow**: if/elif/else, for loops, while loops with nested support
- 🛠️ **Built-ins**: print(), len(), type(), range(), int(), float(), str(), bool()
- ⚡ **Optimized VM**: Stack-based virtual machine for efficient bytecode execution
- 🔧 **Extensible**: Add custom functions to the Python environment

## 🎮 Use Cases

### Game Modding & Player Scripting

PyLua is designed to provide a safe Python scripting environment for games, allowing:

- **Player-created content**: Let players write Python scripts to customize gameplay
- **Safe mod execution**: Run untrusted Python code without security risks
- **Educational games**: Teach programming through Python in a game environment
- **Custom game logic**: Allow advanced users to extend game functionality

### Sandboxed Execution

Similar to how Lupa allows embedding Lua in Python, PyLua provides the inverse - embedding Python in Luau/Roblox environments with:

- Controlled access to game APIs
- Custom built-in functions specific to your game
- Resource limitations and execution timeouts
- Safe error handling and recovery

## 🚀 Quick Start

### Basic Usage

```lua
local PyLua = require('PyLua')

-- Create a Python runtime (like lupa's LuaRuntime())
local python = PyLua.new()

-- Simple evaluation (like lupa's lua.eval)
local result = python:eval('2 + 3')  -- Returns 5
print(result)  -- 5

-- Execute code without return value
python:execute('print("Hello, PyLua!")')
```

### Multiple Isolated Runtimes

```lua
local PyLua = require('PyLua')

-- Create separate runtimes for different contexts (like Lupa)
local player_runtime = PyLua.new()
local admin_runtime = PyLua.new()

-- Each runtime has its own isolated environment
player_runtime:globals().player_level = 5
admin_runtime:globals().admin_privileges = true

-- They don't interfere with each other
local player_result = player_runtime:eval('player_level * 10')  -- Returns 50
local admin_result = admin_runtime:eval('admin_privileges and "Admin" or "User"')  -- Returns "Admin"
```

### Function Definitions and Reuse

```lua
local PyLua = require('PyLua')
local python = PyLua.new()

-- Define a Python function
local calc_func = python:eval([[
def calculate_damage(base, multiplier):
    return int(base * multiplier * 1.5)
]])

-- Use the function multiple times
local damage1 = calc_func(10, 2.5)  -- Returns 37
local damage2 = calc_func(15, 1.8)  -- Returns 40
```

### Custom Environment

```lua
local PyLua = require('PyLua')
local python = PyLua.new()

-- Add Luau functions to Python environment (like lupa's lua.globals())
python:globals().get_player_data = function()
    return {health = 100, mana = 50, level = 5}
end

python:globals().log_event = function(message)
    print("[GAME]", message)
end

-- Python can now call Luau functions
python:execute([[
player = get_player_data()
if player["health"] < 30:
    log_event("Player health is low!")
    
print(f"Player level: {player['level']}")
]])
```

### Game Modding Example

```lua
local PyLua = require('PyLua')

-- Create a runtime for player scripting
local player_runtime = PyLua.new()

-- Set up game functions for Python to use
player_runtime:globals().player_health = 15  -- Low health scenario
player_runtime:globals().set_player_speed = function(speed)
    print("Setting player speed to", speed)
end
player_runtime:globals().set_jump_height = function(height)
    print("Setting jump height to", height)
end

-- Execute player's custom script
player_runtime:execute([[
# Player writes this Python code to customize their experience
player_speed = 16
jump_height = 50

if player_health < 20:
    player_speed = player_speed * 1.5  # Speed boost when low health
    print("Speed boost activated!")

# Call game functions
set_player_speed(player_speed)
set_jump_height(jump_height)
]])
```

### Multiple Player Environments

```lua
local PyLua = require('PyLua')

-- Each player gets their own isolated runtime
local players = {}

function createPlayerRuntime(playerId)
    local runtime = PyLua.new()
    
    -- Player-specific functions
    runtime:globals().get_player_id = function() return playerId end
    runtime:globals().send_message = function(msg)
        print("[Player " .. playerId .. "]", msg)
    end
    
    players[playerId] = runtime
    return runtime
end

-- Player 1's script
local player1 = createPlayerRuntime("Alice")
player1:execute([[
player_id = get_player_id()
send_message(f"Hello from {player_id}!")
]])

-- Player 2's script (completely isolated)
local player2 = createPlayerRuntime("Bob")
player2:execute([[
player_id = get_player_id()
send_message(f"Greetings from {player_id}!")
]])
```

### Data Processing Example

```lua
local PyLua = require('PyLua')
local python = PyLua.new()

-- Process game data and get the result
local sorted_players = python:eval([[
# Process high score data
high_scores = [
    {"player": "Alice", "score": 8500},
    {"player": "Bob", "score": 9200},
    {"player": "Charlie", "score": 7800}
]

# Simple sorting algorithm
for i in range(len(high_scores)):
    highest_index = i
    for j in range(i + 1, len(high_scores)):
        if high_scores[j]["score"] > high_scores[highest_index]["score"]:
            highest_index = j
    
    # Swap
    high_scores[i], high_scores[highest_index] = high_scores[highest_index], high_scores[i]

# Return the sorted list
high_scores
]])

-- Use the result in Luau
for i, player in ipairs(sorted_players) do
    print(i .. ".", player.player, "-", player.score)
end
```

## 📚 API Reference

### `PyLua.new(options?)`

Creates a new Python runtime instance (like Lupa's `LuaRuntime()`).

- **Parameters**: `options` (table, optional) - Runtime configuration
  - `debug` (boolean) - Enable debug output for this runtime
  - `timeout` (number) - Default execution timeout in milliseconds
- **Returns**: Python runtime instance
- **Example**: `local python = PyLua.new({debug = true})`

### Runtime Methods

#### `runtime.eval(code)`

Evaluates Python code and returns the result (like Lupa's `lua.eval()`).

- **Parameters**: `code` (string) - Python expression or statements
- **Returns**: Result value or Python function object
- **Example**: `local result = python:eval('2 + 3')` returns `5`

#### `runtime.execute(code)`

Executes Python code without returning a value (for side effects).

- **Parameters**: `code` (string) - Python statements
- **Returns**: Nothing
- **Example**: `python:execute('print("Hello, World!")')`

#### `runtime.globals()`

Access the Python global environment (like Lupa's `lua.globals()`).

- **Returns**: Table that can be used to set Python global variables
- **Example**: `python:globals().my_func = function(x) return x * 2 end`

### Advanced API (Bytecode)

For performance-critical applications, you can still use the lower-level bytecode API:

#### `runtime.compile(code)`

Compiles Python source code to bytecode for later execution.

- **Parameters**: `code` (string) - Python source code
- **Returns**: `bytecode` (table), `error` (string|nil) - Compiled bytecode or error message

#### `runtime:runBytecode(bytecode, options?)`

Executes pre-compiled bytecode in a sandboxed environment.

- **Parameters:**
  - `bytecode` (table) - Compiled bytecode from `runtime:compile()`
  - `options` (table, optional) - Execution options
    - `debug` (boolean) - Enable debug output
    - `globals` (table) - Custom global environment
- **Returns**: `success` (boolean), `result` (any) - Success status and result

## 🔧 Sandboxing & Security

### Why Use PyLua for Sandboxing?

PyLua provides a safe environment for executing untrusted Python code:

1. **Isolation**: Each runtime runs in its own controlled virtual machine with no access to other runtimes
2. **Resource Control**: Limit memory usage, execution time, and computational resources per runtime
3. **API Control**: Only expose specific functions and capabilities to Python scripts
4. **Error Containment**: Script errors don't crash the host application or affect other runtimes

### Multiple Runtime Isolation

Create separate, isolated environments for different contexts:

```lua
local PyLua = require('PyLua')

-- Trusted admin runtime with full permissions
local admin_runtime = PyLua.new()
admin_runtime:globals().delete_player = function(id)
    print("Deleting player", id)
end
admin_runtime:globals().ban_user = function(id)
    print("Banning user", id)
end

-- Restricted player runtime with limited permissions
local player_runtime = PyLua.new()
player_runtime:globals().get_stats = function()
    return {score = 100, level = 5}
end
-- Note: No admin functions available to players

-- Admin can execute dangerous operations
admin_runtime:execute('delete_player("cheater123")')

-- Player cannot access admin functions (would error)
-- player_runtime:execute('delete_player("someone")')  -- Error: delete_player not defined
```

### Custom Environment Functions

Add game-specific functions to individual runtimes:

```lua
local PyLua = require('PyLua')
local python = PyLua.new()

-- Set up custom environment using globals() (like Lupa)
python:globals().get_player_position = function()
    return {x = 10, y = 5, z = 3}
end

python:globals().move_player = function(x, y, z)
    print("Moving player to", x, y, z)
end

python:globals().get_game_time = function()
    return os.time()
end

-- Python can now use these functions directly
python:execute([[
pos = get_player_position()
print("Current position:", pos["x"], pos["y"], pos["z"])

# Move player forward
new_x = pos["x"] + 5
move_player(new_x, pos["y"], pos["z"])

print("Game time:", get_game_time())
]])
```

## 🔧 Bytecode Management

### Why Use Bytecode?

Bytecode compilation provides several advantages for sandboxing:

1. **Performance**: Compile once, execute many times without re-parsing
2. **Security**: Validate and analyze code at compile time before execution
3. **Caching**: Store pre-compiled scripts for repeated use
4. **Inspection**: Examine bytecode structure for security analysis

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
local PyLua = require('PyLua')

-- Create runtime with debug enabled
local python = PyLua.new({debug = true})

-- Or enable debug mode for bytecode execution
local bytecode = python:compile('x = 42\nprint("x =", x)')
python:runBytecode(bytecode, {debug = true})
```

Debug output includes:

- Stack operations (PUSH/POP)
- Variable assignments
- Function calls
- Instruction execution flow

## 🐍 Supported Python Features

PyLua currently supports a comprehensive subset of Python, making it suitable for most scripting and modding scenarios:

### Data Types

- **Numbers**: Integers and floats with full arithmetic support
- **Strings**: Text with proper escaping and manipulation
- **Booleans**: `True`, `False` with logical operations
- **None**: Python's null value for representing absence

### Data Structures

- **Lists**: `[1, 2, 3]` with indexing, appending, and `len()` support
- **Dictionaries**: `{"key": "value"}` with key access and manipulation
- **Tuples**: `(1, 2, 3)` immutable sequences for data integrity
- **Sets**: `{1, 2, 3}` unique value collections (planned)

### Control Flow

- **Conditionals**: `if`, `elif`, `else` with complex nesting
- **For Loops**: `for item in iterable:` over lists, ranges, and other sequences
- **While Loops**: `while condition:` with proper termination and break conditions

### Built-in Functions

- `print(*args)` - Output values (can be redirected for game logging)
- `len(obj)` - Get length of collections and sequences
- `type(obj)` - Get object type information
- `range(start, stop, step)` - Generate number sequences for iteration
- `int(value)`, `float(value)`, `str(value)`, `bool(value)` - Type conversion functions

### Function Definitions

- **Custom Functions**: `def function_name(parameters):` with local scope
- **Return Values**: Explicit `return` statements and implicit None returns
- **Parameter Passing**: Arguments and local variable isolation
- **Function Calls**: Composition and chaining of user-defined functions

### Operators

- **Arithmetic**: `+`, `-`, `*`, `/`, `%`, `**` for mathematical operations
- **Comparison**: `==`, `!=`, `<`, `<=`, `>`, `>=` for conditional logic
- **Assignment**: `=` for variable binding and updates

## 🚀 Development Roadmap

### Completed Features ✅

- **Core Language**: Variables, operators, expressions, and statements
- **Control Flow**: Complete if/elif/else, for loops, while loops with nesting
- **Data Structures**: Full support for lists, dictionaries, tuples with Python semantics
- **Functions**: User-defined functions with parameters, returns, and local scope
- **Built-ins**: Essential Python functions for basic scripting needs
- **Bytecode VM**: Efficient stack-based virtual machine for code execution

### Planned Features 🔮

- **Classes & OOP**: Python class definitions with inheritance and methods
- **Exception Handling**: `try`/`except`/`finally` blocks for robust error handling
- **Advanced Data Structures**: Sets, frozensets, and enhanced collection operations
- **List Comprehensions**: `[x for x in iterable if condition]` syntax
- **Module System**: Import capabilities for organizing larger scripts
- **Enhanced Security**: Execution timeouts and advanced sandboxing

## 🏗️ Architecture

PyLua uses a secure three-phase architecture designed for safe code execution:

1. **Tokenizer & Parser** (`compiler/tokenizer.luau`): Breaks down Python source into tokens
2. **Compiler** (`compiler/compiler.luau`): Converts tokens into secure bytecode instructions
3. **Virtual Machine** (`vm/bytecode_executor.luau`): Executes bytecode in a controlled environment
4. **Core Libraries** (`core/`): Built-in functions and Python object implementations

```txt
Python Source Code
       ↓
   [Tokenizer] (Security validation)
       ↓
   [Compiler] → Bytecode (Static analysis)
       ↓
  [VM Executor] → Results (Sandboxed execution)
```

This architecture ensures that:

- **No direct code execution**: All Python code goes through compilation first
- **Static validation**: Dangerous constructs can be detected before execution
- **Controlled runtime**: The VM manages all aspects of code execution
- **Resource isolation**: Memory and execution are contained within the VM

## 🤝 Contributing

PyLua is designed to be the inverse of Python's Lupa library - where Lupa allows embedding Lua in Python, PyLua enables embedding Python in Luau/Roblox environments.

We welcome contributions that enhance:

- **Security features**: Better sandboxing and resource controls
- **Python compatibility**: Additional language features and built-ins  
- **Performance optimizations**: Faster compilation and execution
- **API extensions**: More ways to integrate with game environments
- **Documentation**: Examples, tutorials, and best practices

## 📝 License

This repository is under the [`MIT license`](./LICENSE).
