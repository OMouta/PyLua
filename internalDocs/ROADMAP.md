# PyLua Roadmap (Post 0.3)

This document tracks planned work after the 0.3 release. It focuses on future features and enhancements; the rewrite is complete.

Target: Maintain Python 3.12 semantics where practical and expand the supported surface incrementally while preserving the existing Luau embedding API.

## v3.1 — Classes & Modules

Read [MODULES.md](./MODULES.md) for more information about modules and packages.

- [ ] Class definitions and inheritance
- [ ] Module system and imports
- [ ] Package structure

## v3.2 — Advanced Language Features

- [ ] Decorators
- [ ] Context managers (with/enter/exit)
- [ ] Async/await (coroutines)

## v3.3 — Standard Library Surface

- [ ] Core modules (math, string, etc.)
- [ ] File I/O operations (environment-dependent)
- [ ] JSON handling

## v3.4 — Performance & Footprint

- [ ] Bytecode optimizations
- [ ] Potential JIT compilation hooks
- [ ] Memory usage optimizations

## Principles

- CPython-inspired behavior where practical for an embedded interpreter
- Backwards compatibility within the 0.3 line when possible
- Clear, modular implementations with tests and docs for each addition

If you’re proposing a feature, please file an issue referencing this roadmap and include concrete use-cases and minimal examples.
