# Built-in Functions

Implemented in `src/PyLua/builtins/functions.luau`. Highlights:

- `print(*args)` — writes space-separated values; can replace writer for testing
- `len(x)` — length with `__len__` or type-specific rules
- `type(x)` — returns a minimal type object: `<class 'name'>`
- `range([start], stop[, step])` — produces an iterable `range` object
- `int(x)`, `float(x)`, `str(x)`, `bool(x)` — conversions
- `repr(x)`, `ascii(x)` — representation helpers
- `format(value, spec?)` — thin wrapper over Lua string.format with Python-like coercions
- `sum(iterable, start=0)`, `min(...)`, `max(...)`
- `bytes(x)` — from string or list of ints
- `isinstance(obj, type|tuple)` — simple type checks with minimal subtype map (e.g., bool ⊂ int)

Notes:

- `print` writer is replaceable via `Functions.setWriter` for tests
- `bytes` returns a proper `bytes` PyObject; VM also constructs bytes from tagged constants
