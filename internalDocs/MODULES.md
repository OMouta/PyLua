# Modules and Import System Design (v3.1)

> A pragmatic, PEP 451–inspired import system for PyLua that works both inside Roblox (no filesystem) and outside (filesystem available).

## Goals and scope

- One import model that supports multiple environments via pluggable finders/loaders.
- Users can structure code into packages/modules that interact normally (absolute + relative imports).
- Roblox: no direct filesystem. Use builtin/native packages and in-memory mounted packages.
- Outside Roblox: enable filesystem discovery (sys.path-like) in addition to the above.
- Safe-by-default with explicit capabilities/policy to allow powerful modules (e.g., `roblox`, `fs`).

Non-goals for v3.1:

- Full `importlib` API parity.
- Zip/bundle import, bytecode caching, reload/reexec mechanics — tracked as follow-ups.

## Design overview

We implement a simplified version of Python’s modern import system (PEP 302/451):

- sys.modules: cache of loaded modules (handles caching and circular imports).
- ModuleSpec: a descriptor that says how a module will be loaded (name, origin, is_package, search locations, loader).
- Finders: given a module name (and optional path for subpackages), return a ModuleSpec or nil.
- Loaders: given a ModuleSpec, create/exec the module object.
- Resolution order mirrors Python:
  1) sys.modules cache
  2) builtin/native registry (like stdlib shipped with runtime)
  3) sys.meta_path finders (custom importers like memory, roblox, zip, etc.)
  4) sys.path finders (filesystem; only when enabled)

This separates policy (what is allowed to import) from mechanism (how to import).

## Core concepts

- Module object: a Python module represented as a dict-like object with attributes:
  - __name__, __spec__, __package__, __loader__
  - __path__ (packages only: iterable of locations)
  - __file__ (if meaningful for the origin)
- ModuleSpec fields (minimum set):
  - name: full module name (e.g., "a.b.c")
  - origin: string describing source (e.g., "builtin", "memory:/pkg/mod.py", "fs:/abs/path/mod.py")
  - is_package: boolean
  - submodule_search_locations: list of origins/locations when is_package=true
  - loader: object with create_module? and exec_module
- Finder contract:
  - find_spec(fullname: string, path?: list) -> ModuleSpec | nil
- Loader contract:
  - create_module?(spec) -> module | nil (optional; may return nil to use default creation)
  - exec_module(module): must populate/initialize the module

Circular import handling:

- Insert a newly created module into sys.modules before `exec_module` so that cycles resolve to a partially-initialized module (Python semantics).

## Supported module sources (v3.1)

1) Builtin/Native packages

    - Origin: `builtin`
    - Loader: NativeLoader (implemented in Luau) that constructs the module from native objects/functions.
    - Purpose: provide `roblox`, `fs` (outside only), `time`, etc., importable by name without paths.

2) Memory-mounted source packages

    - Origin: `memory:/...` (logical paths).
    - Loader: SourceLoader that reads a source string from an in-memory tree supplied at runtime creation, compiles, and executes it.
    - Purpose: enable normal Python package structure (packages, submodules, relative imports) inside Roblox or in environments without a filesystem.

3) Filesystem packages (outside Roblox only)

    - Origin: `fs:/absolute/path/...`.
    - Loader: SourceLoader that reads from disk, compiles, and executes.
    - Purpose: discover `.py` modules and classic packages (`__init__.py`) via `sys.path`-like search.

Future (not v3.1 core):

- Zip/bundle importer for shipping assets in one blob.
- Bytecode cache.
- Namespace packages (PEP 420) — can be added later.

## Import resolution order

1) sys.modules
2) builtin/native registry
3) sys.meta_path finders (e.g., MemoryImporter)
4) sys.path finders (FilesystemImporter, only when enabled)

The first found spec wins. If loading fails, raise a Python ImportError with context.

## Packages, modules, and relative imports

- Module vs package:
  - Module: a single file; is_package=false; __path__ is absent.
  - Package: a directory with an `__init__.py` (classic) or, later, a namespace package; is_package=true with __path__ set.
- Relative imports:
  - Allowed within packages. We compute the base package from __package__ during import execution.
  - Memory-mounted trees behave exactly like a filesystem tree for import semantics.

Namespace packages (PEP 420):

- Not required for v3.1; plan as a follow-up. Start with classic packages.

## Environment-specific behavior

### Roblox (no filesystem)

- Enable:
  - Builtin/NativeImporter (e.g., `roblox`)
  - MemoryImporter (mounted trees provided at runtime creation)
- Disable:
  - FilesystemImporter
- Policy:
  - Capability-based allowlist/denylist by top-level name (e.g., allow {"roblox", "time"}).
  - Keep Roblox features under a single `roblox` namespace to simplify policy and avoid collisions.

What "packages" mean here:

- Think of them as embedded/frozen Python modules packaged into a memory tree.
- Multiple scripts can live under the same top-level package and import each other normally.

### Outside Roblox (filesystem available)

- Enable:
  - FilesystemImporter (sys.path-like search)
  - Builtin/NativeImporter
  - MemoryImporter (optional, still useful for overrides or embedding app code)
- Configure:
  - Explicit `searchPath` array (do not guess). Classic layout: module.py or package/__init__.py.

## Runtime configuration shape (conceptual)

Expose these knobs on `PyLua.new({...})` without committing to exact field names here; final API goes in `src/PyLua/init.luau` docs.

- importers/meta_path: optional list to add/override finders.
- builtinPackages: map of name -> native module factory/descriptor.
- mounts: map of top-level name -> memory tree of sources (files in logical paths) to expose as packages.
- searchPath: list of absolute paths for filesystem discovery (honored only when `enableFilesystem=true`).
- enableFilesystem: boolean; default false in Roblox, true in desktop CLI contexts.
- policy:
  - allow: set/list of top-level names allowed to import.
  - deny: set/list of names denied (evaluated after allow).
  - safe defaults: when unset, err on deny for powerful modules.

Configuration examples (illustrative):

Roblox:

```luau
local python = PyLua.new({
  enableFilesystem = false,
  builtinPackages = { roblox = RobloxNative },
  mounts = {
    mygame = {
      ["__init__.py"] = "# init...",
      ["core/__init__.py"] = "# core init",
      ["core/player.py"] = "...",
    },
  },
  policy = { allow = {"roblox", "mygame"} },
})
-- import mygame.core.player works; import roblox works
```

Outside Roblox:

```luau
local python = PyLua.new({
  enableFilesystem = true,
  searchPath = { "D:/project/src", "D:/venv/site-packages" },
  builtinPackages = { fs = FSNative },
  mounts = {}, -- optional
  policy = { allow = "*" }, -- or explicit list
})
-- classic discovery via searchPath, plus fs native when allowed
```

## Security & policy

- Default-deny for powerful builtin/native packages unless explicitly allowed.
- Keep Roblox functionality under `roblox.*` for clarity.
- No implicit network, file I/O, or process access without explicit capability.
- Per-runtime isolation: `sys.modules`, policies, and search paths do not bleed across runtimes.

## Error handling

- Resolve to a single ImportError message including module name and attempted origins.
- Include source position (lineno/col) in errors raised during `import` statement compilation/execution where applicable.

## Edge cases

- Circular imports: handled via early insertion into sys.modules.
- Reloading: follow-up feature; keep hooks in design (`__spec__`, `__loader__`) to support later.
- Invalidations: out of scope initially; can be added for FS/zip importers later.
- Versioning: leave to the embedding app; this design focuses on runtime import mechanics.

## Milestones and sequencing (v3.1 Modules & Classes)

1) Minimal import core

    - sys.modules, ModuleSpec, resolution order, `import` and `from ... import ...` in compiler/VM.
    - NativeImporter with a tiny example builtin (e.g., `time` or a stub `roblox`).

2) MemoryImporter + mount API

    - Mount a tree; support absolute and relative imports; circular import tests.
    - Module attributes correctness: __spec__, __package__, __path__, __loader__, __name__.

3) FilesystemImporter (outside only)

    - sys.path-like `searchPath` discovery; classic packages with `__init__.py`.
    - __file__ for FS modules; basic error messages.

4) Policy & capabilities

    - Allow/deny lists and defaults; tests proving enforcement.

5) Documentation

    - Public doc in `docs/MODULES.md` (high-level) and this internal doc.
    - API doc additions in `docs/API.md` for `PyLua.new` config.

6) Optional follow-ups

    - Namespace packages (PEP 420)
    - Zip/bundle importer
    - Reload/invalidation
    - Bytecode caching

## Testing strategy

Unit tests

- Finder/Loader contracts for Native, Memory, Filesystem (when enabled).
- ModuleSpec construction (module vs package), attributes set correctly.
- sys.modules caching and circular import scenarios.

Integration tests

- End-to-end imports from memory and filesystem, including packages and relative imports.
- Policy enforcement: allowed vs denied imports.
- Roblox profile (no FS) vs Desktop profile (with FS).

## Future extensions

- Namespace packages (PEP 420): treat directories without `__init__.py` as packages that can merge over multiple search locations.
- importlib-style APIs for programmatic import control.
- Zip/asset bundle importer for distribution.
- Bytecode caches to speed reloads in desktop environments.

## Quick reference

- Load order: sys.modules → builtin/native → meta_path (Memory, etc.) → sys.path (FS, optional)
- Sources in v3.1: Native (builtin), Memory (mounted), Filesystem (outside only)
- Packages: classic `__init__.py` packages; relative imports supported inside packages
- Config: mount trees and register native packages at `PyLua.new`; opt-in filesystem and searchPath outside Roblox
- Security: capability/allowlist, per-runtime isolation, default-deny for powerful modules
