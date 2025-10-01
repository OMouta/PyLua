# Compiler

Compiles AST into a compact Python-like bytecode executed by the VM.

- File: `src/PyLua/compiler.luau`
- Output: CodeObject with fields: `constants`, `names`, `varnames`, `bytecode`, and metadata

## Pools and indices

- Constants: de-duplicated by a serialized key; nil stored as a sentinel `{ __nil = true }`
- Names: de-duplicated; both constants and names use zero-based indices (like CPython); VM adapts to 1-based tables

## Expressions

- Constants → `LOAD_CONST`
- Name (Load/Store) → `LOAD_NAME` / `STORE_NAME`
- Attribute → `LOAD_ATTR`/`STORE_ATTR`
- Subscript → `LOAD_SUBSCR`/`STORE_SUBSCR`
- Binary ops → `BINARY_*` (incl. `FLOOR_DIVIDE`, `MATRIX_MULTIPLY`)
- Unary ops → `UNARY_*`
- Compare → `COMPARE_OP` with small int tag (0..9); currently single comparator only
- Calls → push func then args; `CALL_FUNCTION argc`
- Collections → `BUILD_LIST`/`BUILD_TUPLE`/`BUILD_SET`/`BUILD_MAP`
- Dict unpacking → `BUILD_MAP_UNPACK` merges multiple dicts; segments built separately then merged
- List comprehension → compiled into a tiny function created via `MAKE_FUNCTION` then immediately `CALL_FUNCTION`

## Statements

- Expr → evaluate + `POP_TOP`
- Assign / AugAssign → load/store targets; attribute/subscript targets supported
  - Tuple assignment targets fully supported with recursive unpacking
- If/elif/else → conditional with `POP_JUMP_IF_FALSE` and `JUMP_FORWARD` (patched)
- While → `SETUP_LOOP` + test/jumps; supports `break`/`continue` and optional `else`
- For → `GET_ITER` + `FOR_ITER` loop; supports tuple destructuring via `UNPACK_SEQUENCE`
  - Simple targets: `for x in items:`
  - Tuple targets: `for x, y in items:` or `for (x, y) in items:`
  - Nested tuples: `for (a, b), c in items:` recursively unpacks
- Return → push value or `None` and `RETURN_VALUE`
- FunctionDef → compiles nested CodeObject and creates a function via `MAKE_FUNCTION`, then `STORE_NAME`
- Module → implicit final `return None`

## Jump patching

- `JUMP_FORWARD` is relative; patched to the right offset from next instruction
- Other jumps are absolute instruction indices (converted to 1-based in VM)

## Known gaps

- Chained comparisons not yet emitted (parser may build them)
- Function defaults/kwargs in `MAKE_FUNCTION` are stubbed
