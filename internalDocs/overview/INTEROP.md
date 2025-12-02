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

## Bind custom Luau objects

`PyLua.registerClassBinding` lets you describe how Luau userdata/tables should appear inside Python. Provide a predicate (or Luau `typeof` string) and PyLua will wrap matching values in a Python-side proxy that supports attribute access and method calls.

```lua
local PyLua = require("./src/PyLua")

PyLua.registerClassBinding({
  pyTypeName = "Widget",
  predicate = function(value)
    return type(value) == "table" and value.__kind == "Widget"
  end,
})

local runtime = PyLua.new()
local globals = runtime:globals()

globals.widget = {
  __kind = "Widget",
  value = 10,
  increment = function(self, amount)
    self.value += amount
    return self.value
  end,
}

runtime:execute([[ before = widget.value
after = widget.increment(5)
widget.value = after + 1 ]])

print(globals.before)        --> 10
print(globals.after)         --> 15
print(globals.widget.value)  --> 16
```

- Methods are automatically bound with the Luau instance as the first argument; set `bindSelf = false` for static-style helpers.
- Override `getAttr`/`setAttr` to customise attribute access, and `toLuau` to control how proxies round-trip back into Luau.
- Use `PyLua.clearClassBindings()` in tests to reset global registrations.

## Current status (0.3.0‑dev)

- Globals remain the primary bridge for sharing values between Luau and Python.
- Custom userdata/tables can participate in Python code via `PyLua.registerClassBinding`, including method calls and attribute mutation.

## Planned two‑way binding

The final interop will support true two‑way calls and richer conversions:

- Pass Luau functions to Python and call them from Python code
- Pass Python callables back to Luau and call them from Luau
- Automatic discovery for complex userdata/metatable hierarchies without manual predicates
- Broader error translation in both directions (Python exceptions ↔ Luau errors)

This will make the example above fully supported and enable patterns like event callbacks and service injection across the boundary.

See also:

- [API guide](docs/API.md)
- [Limitations](docs/LIMITATIONS.md)
