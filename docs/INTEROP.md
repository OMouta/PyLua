# Interop (Luau ↔ Python)

Use the runtime `globals()` to share values/functions between Luau and Python.

## Expose a Luau function to Python

```lua
local PyLua = require("./src/PyLua")
local py = PyLua.new()
local g = py:globals()

g.lua_mul = function(a: number, b: number): number
  return a * b
end

py:execute([[ result = lua_mul(6, 7) ]])
print(g.result) -- 42
```

- Globals table is the Python `globals()` for executed code
- VM unwraps certain primitives on exit to ease reading values back in Luau

## Current status (0.3.0‑dev)

- Globals are the primary bridge: read/write plain values between Luau and Python.
- Passing bare Luau functions into Python and calling them from Python is under active development. Depending on the build, a raw Luau function placed in `globals()` may not yet be callable by Python code.

## Planned two‑way binding

The final interop will support true two‑way calls and richer conversions:

- Pass Luau functions to Python and call them from Python code
- Pass Python callables back to Luau and call them from Luau
- Automatic conversion for common types (numbers, strings, bytes, lists/tuples/sets/dicts) with sensible fallbacks
- Error translation in both directions (Python exceptions ↔ Luau errors)

This will make the example above fully supported and enable patterns like event callbacks and service injection across the boundary.

See also:

- [API guide](docs/API.md)
- [Limitations](docs/LIMITATIONS.md)
