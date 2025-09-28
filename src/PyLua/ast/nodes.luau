local Nodes = {}

-- Operator types
export type UnaryOpType = "Invert" | "Not" | "UAdd" | "USub"
export type BinOpType =
	"Add"
	| "Sub"
	| "Mult"
	| "MatMult"
	| "Div"
	| "Mod"
	| "Pow"
	| "LShift"
	| "RShift"
	| "BitOr"
	| "BitXor"
	| "BitAnd"
	| "FloorDiv"
export type CmpOp = "Eq" | "NotEq" | "Lt" | "LtE" | "Gt" | "GtE" | "Is" | "IsNot" | "In" | "NotIn"
export type BoolOpType = "And" | "Or"

-- Base AST node type with source location information
export type ASTNode = {
	type: string, -- Node type identifier
	lineno: number, -- Source line number
	col_offset: number, -- Column offset
	end_lineno: number?, -- End line number
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

-- MODULE
-- Module node (top-level container)
export type Module = ASTNode & {
	type: "Module",
	body: { Stmt },
	type_ignores: { any }?, -- For type: ignore comments
}

-- STATEMENTS
-- Assignment statement: x = 1, x, y = 1, 2
export type Assign = Stmt & {
	type: "Assign",
	targets: { Expr }, -- Left-hand side expressions
	value: Expr, -- Right-hand side expression
}

-- Augmented assignment: x += 1
export type AugAssign = Stmt & {
	type: "AugAssign",
	target: Expr, -- Left-hand side
	op: BinOpType, -- Operator
	value: Expr, -- Right-hand side
}

-- Expression statement: function_call()
export type ExprStmt = Stmt & {
	type: "Expr",
	value: Expr,
}

-- If statement: if condition: ... elif condition: ... else: ...
export type If = Stmt & {
	type: "If",
	test: Expr, -- Condition
	body: { Stmt }, -- If body
	orelse: { Stmt }, -- Else/elif body
}

-- While loop: while condition: ...
export type While = Stmt & {
	type: "While",
	test: Expr, -- Condition
	body: { Stmt }, -- Loop body
	orelse: { Stmt }, -- Else clause
}

-- For loop: for target in iter: ...
export type For = Stmt & {
	type: "For",
	target: Expr, -- Loop variable
	iter: Expr, -- Iterable
	body: { Stmt }, -- Loop body
	orelse: { Stmt }, -- Else clause
}

-- Function definition: def name(args): ...
export type FunctionDef = Stmt & {
	type: "FunctionDef",
	name: string, -- Function name
	args: Arguments, -- Parameters
	body: { Stmt }, -- Function body
	decorator_list: { Expr }, -- Decorators
	returns: Expr?, -- Return type annotation
}

-- Class definition: class Name(bases): ...
export type ClassDef = Stmt & {
	type: "ClassDef",
	name: string, -- Class name
	bases: { Expr }, -- Base classes
	keywords: { Keyword }, -- Keyword arguments
	body: { Stmt }, -- Class body
	decorator_list: { Expr }, -- Decorators
}

-- Return statement: return value
export type Return = Stmt & {
	type: "Return",
	value: Expr?, -- Return value (optional)
}

-- Break statement: break
export type Break = Stmt & {
	type: "Break",
}

-- Continue statement: continue
export type Continue = Stmt & {
	type: "Continue",
}

-- Pass statement: pass
export type Pass = Stmt & {
	type: "Pass",
}

-- EXPRESSIONS
-- Binary operation: left op right
export type BinOpNode = Expr & {
	type: "BinOp",
	left: Expr, -- Left operand
	op: BinOpType, -- Operator
	right: Expr, -- Right operand
}

-- Unary operation: op operand
export type UnaryOpNode = Expr & {
	type: "UnaryOp",
	op: UnaryOpType, -- Operator
	operand: Expr, -- Operand
}

-- Boolean operation: left op right (and/or)
export type BoolOpNode = Expr & {
	type: "BoolOp",
	op: BoolOpType, -- Operator (And/Or)
	values: { Expr }, -- Operands (2 or more)
}

-- Comparison: left ops comparators
export type Compare = Expr & {
	type: "Compare",
	left: Expr, -- Left operand
	ops: { CmpOp }, -- Comparison operators
	comparators: { Expr }, -- Right operands
}

-- Function call: func(args, keywords)
export type Call = Expr & {
	type: "Call",
	func: Expr, -- Function to call
	args: { Expr }, -- Positional arguments
	keywords: { Keyword }, -- Keyword arguments
}

-- Attribute access: value.attr
export type Attribute = Expr & {
	type: "Attribute",
	value: Expr, -- Object
	attr: string, -- Attribute name
	ctx: ExprContext, -- Load/Store/Del context
}

-- Subscript: value[slice]
export type Subscript = Expr & {
	type: "Subscript",
	value: Expr, -- Object
	slice: Expr, -- Index/slice
	ctx: ExprContext, -- Load/Store/Del context
}

-- Variable name: identifier
export type Name = Expr & {
	type: "Name",
	id: string, -- Identifier name
	ctx: ExprContext, -- Load/Store/Del context
}

-- Constant value: 42, "hello", True, None
export type Constant = Expr & {
	type: "Constant",
	value: any, -- The constant value
	kind: string?, -- String prefix for string literals
}

-- List literal: [1, 2, 3]
export type List = Expr & {
	type: "List",
	elts: { Expr }, -- Elements
	ctx: ExprContext, -- Load/Store/Del context
}

-- Tuple literal: (1, 2, 3)
export type Tuple = Expr & {
	type: "Tuple",
	elts: { Expr }, -- Elements
	ctx: ExprContext, -- Load/Store/Del context
}

-- Dictionary literal: {'key': 'value'}
export type Dict = Expr & {
	type: "Dict",
	keys: { Expr }, -- Keys (DictUnpack sentinel nodes for ** entries)
	values: { Expr }, -- Values
}

-- Set literal: {1, 2, 3}
export type Set = Expr & {
	type: "Set",
	elts: { Expr }, -- Elements
}

-- List comprehension: [elt for target in iter if ...]
export type Comprehension = {
	target: Expr,
	iter: Expr,
	ifs: { Expr },
	is_async: boolean,
}

export type ListComp = Expr & {
	type: "ListComp",
	elt: Expr,
	generators: { Comprehension },
}

-- Starred expression: *value (in lists, tuples, calls)
export type Starred = Expr & {
	type: "Starred",
	value: Expr,
	ctx: ExprContext,
}

-- Dict **unpack sentinel inside a dict literal (mirrors CPython using None in keys list)
export type DictUnpack = Expr & {
	type: "DictUnpack",
	value: Expr,
}

-- HELPER TYPES
-- Expression context (how the expression is used)
export type ExprContext = "Load" | "Store" | "Del"

-- Function arguments
export type Arguments = {
	posonlyargs: { Arg }, -- Positional-only arguments
	args: { Arg }, -- Regular arguments
	vararg: Arg?, -- *args
	kwonlyargs: { Arg }, -- Keyword-only arguments
	kw_defaults: { Expr? }, -- Keyword argument defaults
	kwarg: Arg?, -- **kwargs
	defaults: { Expr }, -- Default values
}

-- Function argument
export type Arg = {
	arg: string, -- Argument name
	annotation: Expr?, -- Type annotation
	lineno: number,
	col_offset: number,
	end_lineno: number?,
	end_col_offset: number?,
}

-- Keyword argument
export type Keyword = {
	arg: string?, -- Keyword name (None for **)
	value: Expr, -- Value
	lineno: number,
	col_offset: number,
	end_lineno: number?,
	end_col_offset: number?,
}

-- Union type for all statement types
export type AnyStmt =
	Assign
	| AugAssign
	| ExprStmt
	| If
	| While
	| For
	| FunctionDef
	| ClassDef
	| Return
	| Break
	| Continue
	| Pass

-- Union type for all expression types
export type AnyExpr =
	BinOpNode
	| UnaryOpNode
	| BoolOpNode
	| Compare
	| Call
	| Attribute
	| Subscript
	| Name
	| Constant
	| List
	| Tuple
	| Dict
	| Set
	| ListComp
	| Starred
	| DictUnpack

-- Union type for all AST node types
export type AnyNode = Module | AnyStmt | AnyExpr

-- UTILITY FUNCTIONS
-- Create a new AST node with source location
function Nodes.new_node(node_type: string, lineno: number, col_offset: number): ASTNode
	return {
		type = node_type,
		lineno = lineno,
		col_offset = col_offset,
		end_lineno = nil,
		end_col_offset = nil,
	}
end

-- Set end location for an AST node
function Nodes.set_end_location(node: ASTNode, end_lineno: number, end_col_offset: number): ASTNode
	node.end_lineno = end_lineno
	node.end_col_offset = end_col_offset
	return node
end

-- Copy location information from one node to another
function Nodes.copy_location(from_node: ASTNode, to_node: ASTNode): ASTNode
	to_node.lineno = from_node.lineno
	to_node.col_offset = from_node.col_offset
	to_node.end_lineno = from_node.end_lineno
	to_node.end_col_offset = from_node.end_col_offset
	return to_node
end

return Nodes
