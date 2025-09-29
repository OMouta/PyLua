# PyLua API

This guide explains the public API users interact with when embedding Python in Luau. It reflects the current v0.3.0‑dev implementation.

## Importing

From this repository when running with Lute:

```lua
-- From docs/examples/* the relative import is:
local PyLua = require("../../src/PyLua")

-- From the repo root or your own project layout, adjust the path accordingly,
-- e.g. local PyLua = require("src/PyLua").
```

## Creating a runtime

```lua
local py = PyLua.new({
  debug = false,     -- optional; enables extra diagnostics in some subsystems
  timeout = 0,       -- optional; planned, not enforced yet in v0.3.0‑dev
  maxRecursion = 0,  -- optional; planned guard, not enforced yet
  builtins = nil,    -- optional; override built-ins
})
```

Notes:

- A PyLua runtime holds its own globals and built-ins table.
- The globals table is pre-populated with `__pylua_version__`, `__name__ = "__main__"`, and a few standard dunders.

## Running code

### execute(code)

Run Python statements. Returns no value; exceptions raise Luau errors.

```lua
py:execute([[ 
    x = [1, 2, 3]
    y = { 'name': 'test', 'value': 42 }
    print("sum:", sum(x))
]])
```

### eval(code) -> any

Evaluate a single Python expression and return its value (converted when reasonable).

```lua
local v = py:eval("1 + 2 * 3")  -- 7
```

Edge cases:

- `eval` requires an expression (not statements); use `execute` otherwise.
- Errors are thrown as Luau `error(...)`; use `pcall` to handle them.

### compile(code) -> CodeObject

Compile Python source to a code object (bytecode + pools).

```lua
local co = py:compile("1 + 2")
-- co has fields: constants, names, varnames, bytecode, ...
```

### runBytecode(codeObject) -> any

Execute a previously compiled code object.

```lua
local result = py:runBytecode(co)
```

## Sharing values via globals

Each runtime has a separate global namespace.

```lua
-- Write from Luau, read from Python
py:setGlobal("answer", 42)
py:execute("print(answer)")

-- Or mutate via the table directly
local g = py:globals()
g.threshold = 10
py:execute("print(threshold)")

-- Read back results written in Python
py:execute("result = sum([1, 2, 3])")
print(g.result) -- 6
```

Helpers:

- `py:globals()` returns the globals table
- `py:setGlobal(name, value)` and `py:getGlobal(name)` access single values

Type notes:

- Numbers, booleans, strings, lists/tuples/dicts/sets created in Python are exposed via PyLua’s object model.
- On return from the VM, some primitives are unwrapped for convenience (e.g., `int` → Luau number).

## Capturing output / customizing builtins

`print(...)` is implemented in `src/PyLua/builtins/functions.luau` and supports swapping the writer for tests/tools.

```lua
local Builtins = require("src/PyLua/builtins/functions")
local lines = {}
Builtins.setWriter(function(s) table.insert(lines, s) end)

py:execute("print('hello')")
-- lines now contains { "hello" }
```

Providing a custom builtins table via `PyLua.new({ builtins = ... })` is also possible, but most use cases are covered by adjusting the writer.

## Interop notes

- Globals are the simplest way to bridge data in and out.
- Calling Luau functions from Python is planned but not yet implemented in this build.
  - Workaround: call from Luau by evaluating Python expressions that read/write globals.

Example pattern:

```lua
-- Expose a Luau value and read back a result
local g = py:globals()
g.n = 5
py:execute("result = [i*i for i in range(n)]")
print(g.result) -- e.g., [0, 1, 4, 9, 16]
```

## Error handling

Use `pcall` around API calls to catch errors raised from Python execution.

```lua
local ok, err = pcall(function()
  py:execute("1/0")
end)
if not ok then
  warn("Python error:", err)
end
```

## Feature support and limits

Target: Python 3.12 syntax and a practical core subset.

Highlights supported:

- Statements: assignment, if/elif/else, while/for (with break/continue), def
- Expressions: arithmetic/bitwise, comparisons, calls, attribute/subscript
- Collections: list/tuple/set/dict literals; list comprehensions
- Builtins: `print`, `len`, `type`, `range`, `int/float/str/bool`, `sum/min/max`, `bytes`, `repr/ascii/format`, `isinstance`

Important limitations (v0.3.0‑dev):

- Chained comparisons parsed but not yet compiled
- Dict unpacking in literals not yet compiled
- For-loop assignment targets beyond simple `Name` unsupported
- Function defaults/kwargs are stubbed in function creation
- Exceptions/try-except not implemented
- f-strings tokenized; full runtime formatting in progress

See [LIMITATIONS.md](LIMITATIONS.md) for the up-to-date list.

## Version

The runtime exposes `__pylua_version__` in globals:

```lua
print(py:globals().__pylua_version__)
```
