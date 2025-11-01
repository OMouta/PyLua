# PyLua - Embedded Python for Luau

> For v0.2 docs, see [docs/0.2/README.md](docs/0.2/README.md).

Run Python inside Luau (e.g., Roblox). PyLua 0.3 is a compact, CPython‑inspired interpreter you can embed in Luau projects.

## Highlights

- Python 3.12 (and below) semantics where practical
- Works with [Lute] and Luau runtimes (Roblox Studio, etc.)
- Simple API: execute/eval and share values via `globals()`
- CPython‑style pipeline (lexer → parser → AST → bytecode → VM)

## Quick start

Run an example from the repo root (requires Lute in PATH):

```powershell
lute examples/hello_world.luau
```

Embed and run a bit of Python:

```lua
local PyLua = require("./src/PyLua")
local py = PyLua.new()

py:execute([[x = 2 + 3]])
print(py:getGlobal("x")) -- 5

local result = py:eval("sum([1, 2, 3])")
print(result) -- 6
```

## Docs and examples

- Docs index: `docs/README.md`
- Architecture overview: `docs/ARCHITECTURE.md`
- Examples: `examples/`

## Status

- Version: `0.3.0`
- Target: Python 3.12 and below (3.13+ out of scope)
- Roadmap: `internalDocs/ROADMAP.md`

## Contributing

Issues and PRs welcome. See `CONTRIBUTING.md` for guidelines.

## License

MIT — see [`LICENSE`](./LICENSE).

[Lute]: https://github.com/luau-lang/lute
