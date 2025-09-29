# Current Limitations (0.3.0-dev)

A practical subset is implemented; some features are deferred or partial:

- Comparisons: chained comparisons parsed but compiler currently emits only single comparator; VM supports compare tags
- Dict unpacking (`{**d, ...}`) not yet compiled
- For-loop targets: only simple `Name` targets compiled (no tuple destructuring yet)
- Function defs: default args/kwargs are stubbed; `MAKE_FUNCTION` ignores defaults
- Exceptions: structured exception handling not implemented
- f-strings: prefixes tokenized; full runtime interpolation/formatting still in progress
- Interop: calling Luau from Python is minimal; broader object conversion and error translation planned

Track progress in [REWRITE_PLAN.md](../internalDocs/REWRITE_PLAN.md).
