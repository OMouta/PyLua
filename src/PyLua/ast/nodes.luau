--!strict
-- PyLua AST Node Definitions
-- Phase 1.3 - Python AST node types

local Nodes = {}

-- Base AST node type
export type ASTNode = {
    type: string,           -- Node type identifier
    lineno: number,         -- Source line number  
    col_offset: number,     -- Column offset
    end_lineno: number?,    -- End line number
    end_col_offset: number?, -- End column offset
}

-- Expression base type
export type Expr = ASTNode & {
    -- All expressions inherit from this
}

-- Statement base type  
export type Stmt = ASTNode & {
    -- All statements inherit from this
}

-- Module node (top-level)
export type Module = ASTNode & {
    type: "Module",
    body: {Stmt},
}

-- TODO: Define all Python AST node types in Phase 1.3
-- Examples:
-- - Assign, AugAssign
-- - If, While, For
-- - FunctionDef, ClassDef
-- - BinOp, UnaryOp, Compare
-- - Call, Attribute, Subscript
-- - List, Dict, Tuple, Set
-- - Constant, Name

return Nodes
