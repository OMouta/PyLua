# Bytecode and Instructions

PyLua uses a small, Python-inspired instruction set. An instruction is `{ opcode: string, arg?: number, lineno?: number }`.

Key groups:

- Stack ops: `POP_TOP`, `ROT_TWO`, `ROT_THREE`, `DUP_TOP`
- Constants and names: `LOAD_CONST`, `LOAD_NAME`, `STORE_NAME`, `LOAD_ATTR`, `STORE_ATTR`, `LOAD_SUBSCR`, `STORE_SUBSCR`
- Binary ops: `BINARY_ADD`, `BINARY_SUBTRACT`, `BINARY_MULTIPLY`, `BINARY_DIVIDE`, `BINARY_MODULO`, `BINARY_POWER`, `BINARY_FLOOR_DIVIDE`, `BINARY_LSHIFT`, `BINARY_RSHIFT`, `BINARY_OR`, `BINARY_XOR`, `BINARY_AND`, `BINARY_MATRIX_MULTIPLY`
- Unary ops: `UNARY_POSITIVE`, `UNARY_NEGATIVE`, `UNARY_NOT`, `UNARY_INVERT`
- Compare: `COMPARE_OP` with arg mapping (0..9) for `<, <=, ==, !=, >, >=, is, is not, in, not in`
- Control flow: `JUMP_FORWARD`, `POP_JUMP_IF_TRUE`, `POP_JUMP_IF_FALSE`, `JUMP_IF_TRUE_OR_POP`, `JUMP_IF_FALSE_OR_POP`, `SETUP_LOOP`, `POP_BLOCK`, `BREAK_LOOP`, `CONTINUE_LOOP`, `RETURN_VALUE`
- Iteration: `GET_ITER`, `FOR_ITER`
- Unpacking: `UNPACK_SEQUENCE` - unpacks a sequence (list/tuple) into N values on the stack
- Collections: `BUILD_LIST`, `BUILD_TUPLE`, `BUILD_SET`, `BUILD_MAP`, `BUILD_MAP_UNPACK`
- Functions: `MAKE_FUNCTION`, `CALL_FUNCTION`

## UNPACK_SEQUENCE

**Opcode**: `UNPACK_SEQUENCE`  
**Argument**: Count of values to unpack (N)  
**Stack Effect**: Replaces TOS with N values

Pops a sequence (list, tuple, or set) from the top of the stack and pushes its elements onto the stack in reverse order (rightmost element pushed first). Validates that the sequence has exactly N elements, raising `ValueError` if the count doesn't match.

Example:

```python
for x, y in [(1, 2), (3, 4)]:
    print(x + y)
```

Bytecode includes:

- `FOR_ITER` → pushes tuple `(1, 2)` onto stack
- `UNPACK_SEQUENCE 2` → pops tuple, pushes `2` then `1`
- `STORE_NAME` (for x) → pops `2`, stores in `x`
- `STORE_NAME` (for y) → pops `1`, stores in `y`

Constants:

- Numbers, strings, bools, None; bytes literals stored as tagged constants to construct at runtime
