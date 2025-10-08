# Current Limitations (0.3.0-dev)

A practical subset is implemented; some features are deferred or partial:

- Comparisons: identity (`is`) and membership (`in`) semantics are simplified compared to CPython
- Exceptions: structured exception handling not implemented
- f-strings: prefixes tokenized; full runtime interpolation/formatting still in progress
- Interop: calling Luau from Python is minimal; broader object conversion and error translation planned

Track progress in [REWRITE_PLAN.md](../internalDocs/REWRITE_PLAN.md).
