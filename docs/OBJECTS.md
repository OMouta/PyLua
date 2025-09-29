# Object Model

PyLua implements a lightweight Python-like object system in Luau.

## PyObject shape

```lua
{
  __type: string,        -- Python type name
  __value: any,          -- underlying Luau value or structured data
  __dict: { [k: string]: PyObject }?,
  __typeobj: PyType,     -- type descriptor with methods
}
```

## Type registry

- Register types via `Base.registerType(name, { methods = {...} })`
- Look up via `Base.getTypeObject(name)`
- Primitives bootstrapped: `int`, `float`, `str`, `bool`, `NoneType`, `bytes`, and meta `builtin_function_or_method`

## Attribute access

- `Base.getattr(obj, name)` checks instance `__dict`, then type methods (binding a method), then optional `__getattr` hook
- `Base.setattr(obj, name, value)` writes to `__dict` or uses `__setattr` hook

## Call and operators

- `Base.call(callable, args)` invokes built-in bound methods and built-in functions
- `Base.operate(name, left, right)` tries `__add__` then `__radd__` etc. (see map in `objects/base.luau`)
- `Base.unary(name, obj)` for unary dunder
- `Base.truthy(obj)` implements Python truthiness rules across core types

## Convenience constructors

- `Base.newInt`, `Base.newFloat`, `Base.newBytes`
- `Base.ensurePyObject` wraps primitives into PyObjects for VM use
