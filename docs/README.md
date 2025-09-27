# PyLua Documentation (v0.3 dev)

Welcome to the living docs for the PyLua 0.3 rewrite. This version is a ground-up interpreter for running Python 3.12- on Luau. It’s in active development; see `internalDocs/REWRITE_PLAN.md` for the roadmap and supported features.

If you’re just looking to try things, the examples below are the best starting point.

## Examples

All examples live in `docs/examples/` and can be run directly with [Lute]. They exercise the public API in `src/PyLua/init.luau`:

- `hello_world.luau` – tiny smoke test printing the version and a greeting
- `basics.luau` – execute vs eval, sharing values through `globals()`
- `builtins.luau` – `print`, `len`, `type`, iterating `range`
- `collections.luau` – list/tuple/dict/set literals, iteration, `len/min/max/sum`
- `control_flow.luau` – `if/elif/else`, `while`, `for`, `break`/`continue`
- `functions.luau` – defining and calling Python functions, results back in Luau
- `bytes_and_strings.luau` – string vs bytes, indexing, concatenation
- `interop_minimal.luau` – pass a Luau function into Python via `globals()`

## Running the examples

From the repo root:

1) Ensure you have [Lute] installed and available in PATH.

2) Run any example like this:

```powershell
lute docs/examples/hello_world.luau
lute docs/examples/basics.luau
```

## Current API surface

Create a runtime and run code:

```lua
local PyLua = require("src/PyLua")
local py = PyLua.new({ debug = false })

py:execute([[print("hi")]])
local v = py:eval("1 + 2")

print(v) -- 3
```

Useful methods:

- `Runtime:execute(code: string)` – run statements
- `Runtime:eval(code: string): any` – evaluate an expression and return the result
- `Runtime:compile(code: string)` and `Runtime:runBytecode(bytecode)` – advanced use
- `Runtime:globals()` / `setGlobal(name, value)` / `getGlobal(name)` – share values

---

[Lute]: https://github.com/luau-lang/lute
