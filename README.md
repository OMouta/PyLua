# PyLua - Embedded Python for Luau

> For v0.2 docs, see [docs/0.2/README.md](docs/0.2/README.md).

Run Python inside Luau (e.g., Roblox). PyLua is a compact, CPython‑inspired interpreter you can embed in Luau projects.

## Quick Start

### Installation

#### Manual

- Download the latest release from Releases
- Place the PyLua module in your ReplicatedStorage for roblox projects, or your project folder for other Luau projects.

#### Jelly

- Install with jelly

```shell
jelly install omouta/pylua
```

#### Wally

- Add PyLua to wally.toml

```toml
pylua = "omouta/pylua@MAJOR.MINOR.PATCH"
```

- Install with wally

```shell
wally install
```

### Use PyLua

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

- Version: `0.3.1`
- Target: Python 3.12 and below (3.13+ out of scope)
- Roadmap: `internalDocs/ROADMAP.md`

## Contributing

Issues and PRs welcome. See `CONTRIBUTING.md` for guidelines.

## License

MIT - see [`LICENSE`](./LICENSE).
