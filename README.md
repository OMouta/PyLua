# PyLua — Embedded Python Interpreter for Luau

> Notice: For v0.2 docs, see [docs/other/0.2.md](docs/other/0.2.md).

PyLua lets you run Python inside Luau (e.g., Roblox). The v0.3 rewrite is a proper interpreter built in Luau with a CPython-inspired design.

## What is it?

- A Python 3.12-and-below interpreter implemented in Luau
- Runs on [Lute] and other Luau-compatible runtimes
- Embeddable API for executing/evaluating Python and sharing values via `globals()`

## Use cases

- Author gameplay logic in Python while running on Luau
- Build modding hooks: expose Luau callbacks to Python scripts
- Teach/prototype Python inside Roblox-like environments
- Explore interpreter architecture (tokens → AST → bytecode → VM)

## How it’s built

Interpreter pipeline:

- Lexer → Parser → AST → Compiler → Bytecode → VM

Key modules (see `src/PyLua/`):

- `lexer.luau`, `parser/` – Python-compliant tokenization and parsing
- `compiler.luau` – compile AST to bytecode
- `vm/` – stack-based virtual machine
- `objects/` – Python object model
- `builtins/` – core built-in functions and types

## Status

- Version: `0.3.0-dev`
- Target: Python 3.12 syntax and below (3.13+ out of scope)
- Roadmap: `internalDocs/REWRITE_PLAN.md`

## Get started

See docs and examples for usage and API details:

- Docs home: `docs/README.md`
- Examples: `docs/examples/`

You can also quickly try an example with Lute from the repo root:

```powershell
lute docs/examples/hello_world.luau
```

## License

MIT — see [`LICENSE`](./LICENSE).

[Lute]: https://github.com/luau-lang/lute
