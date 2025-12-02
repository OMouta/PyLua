# PyLua Documentation (v0.3)

Welcome to the PyLua 0.3 docs. This version is a ground-up interpreter for running Python 3.12- on Luau. For planned post-0.3 work, see the [Roadmap](../internalDocs/ROADMAP.md).

If you’re just looking to try things, the examples below are the best starting point.

## Examples

All examples live in `examples/` and can be run directly with [Lute]. They exercise the public API in `src/PyLua/init.luau`:

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

```bash
lute examples/hello_world.luau
lute examples/basics.luau
```

## Current API surface

See the full [API documentation](API.md) for details.

Create a runtime and run code:

```lua
local PyLua = require("./src/PyLua")
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

## Guides

Deep dives and references:

- [Architecture](./ARCHITECTURE.md)
- [Lexer](./LEXER.md)
- [Parser](./PARSER.md) & [AST](./AST.md)
- [Compiler](./COMPILER.md)
- [Bytecode](./BYTECODE.md)
- [Virtual Machine](./VM.md)
- [Object Model](./OBJECTS.md)
- [Built-ins](./BUILTINS.md)
- [Interop](./INTEROP.md)
- [Testing](./TESTING.md)
- [Limitations](./LIMITATIONS.md)
- [Roadmap](../internalDocs/ROADMAP.md)
- [MODULES](./MODULES.md)

## Running tests

You can run the full test suite via Lute from the repo root:

```bash
lute tests/run_tests.luau
```

or with Jelly:

```bash
jelly run test
```

This will execute unit and integration tests for the lexer, parser, object model, bytecode, VM, and builtins.

[Lute]: https://github.com/luau-lang/lute
