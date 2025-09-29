# Virtual Machine

Executes bytecode using a stack and frames, with separate globals and builtins environments.

## State

- `current_frame`: active frame
- `call_stack`: list of frames
- `globals`: runtime global variables
- `builtins`: built-in functions available to executed code
- `return_value`: last function/module return

## Frames and stack

- Frame holds bytecode, program counter, operand stack, local vars, and a simple block stack for loops
- Stack helpers in `vm/stack.luau` implement typical stack ops

## Instruction semantics

- Unwrap/rewrap: VM unwraps some primitive PyObjects on exit, and ensures operands are PyObjects before calling into object model
- Comparison tags (0..9) implement `<, <=, ==, !=, >, >=, is, is not, in, not in`
- Iteration protocol:
  - `GET_ITER` creates an internal iterator for list/tuple/set/dict/str/range
  - `FOR_ITER` pulls next value or jumps to end when exhausted
- Collections builders assemble proper `list`, `tuple`, `set`, and `dict` via the object layer
- Function calls:
  - Builtins call through `Base.call`
  - Python functions are executed by constructing a frame from their code object (see `objects/functions.luau`)

## Control flow & loops

- `SETUP_LOOP`/`POP_BLOCK` form a loop block; `BREAK_LOOP` jumps to end, `CONTINUE_LOOP` jumps to loop start
- `JUMP_FORWARD` is relative; others are absolute indices
