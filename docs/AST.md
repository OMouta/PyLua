# AST Nodes

The AST mirrors Python shapes at a pragmatic subset. Nodes carry line/column info.

- Base shape: `{ type: string, lineno: number, col_offset: number, ... }`
- Expressions (subset): Constant, Name, Attribute, Subscript, BinOp, UnaryOp, Compare, Call, List, Tuple, Set, Dict, ListComp
- Statements (subset): Expr, Assign, AugAssign, Return, If, While, For, Break, Continue, Pass, FunctionDef, Module

Location fields:

- `lineno`, `col_offset` are set on all nodes produced by the parser
- Some compiler-generated helper nodes (e.g., listcomp transforms) propagate positions where feasible

See `src/PyLua/ast/nodes.luau` for exact type definitions.
