--!strict
-- PyLua Bytecode Opcodes
-- Phase 4 - Python-like instruction set

local Opcodes = {}

-- Python-like opcodes (based on CPython)
export type Opcode =
	-- Stack manipulation
	"POP_TOP"
	| "ROT_TWO"
	| "ROT_THREE"
	| "DUP_TOP"
	-- Variables
	| "LOAD_CONST"
	| "LOAD_NAME"
	| "STORE_NAME"
	| "DELETE_NAME"
	| "LOAD_FAST"
	| "STORE_FAST"
	| "DELETE_FAST"
	| "LOAD_GLOBAL"
	| "STORE_GLOBAL"
	| "DELETE_GLOBAL"
	-- Binary operations
	| "BINARY_ADD"
	| "BINARY_SUBTRACT"
	| "BINARY_MULTIPLY"
	| "BINARY_DIVIDE"
	| "BINARY_MODULO"
	| "BINARY_POWER"
	| "BINARY_LSHIFT"
	| "BINARY_RSHIFT"
	| "BINARY_OR"
	| "BINARY_XOR"
	| "BINARY_AND"
	-- Unary operations  
	| "UNARY_POSITIVE"
	| "UNARY_NEGATIVE"
	| "UNARY_NOT"
	| "UNARY_INVERT"
	-- Comparison
	| "COMPARE_OP"
	-- Control flow
	| "JUMP_FORWARD"
	| "JUMP_IF_TRUE_OR_POP"
	| "JUMP_IF_FALSE_OR_POP"
	| "POP_JUMP_IF_TRUE"
	| "POP_JUMP_IF_FALSE"
	-- Function calls
	| "CALL_FUNCTION"
	| "RETURN_VALUE"
	-- Object operations
	| "LOAD_ATTR"
	| "STORE_ATTR"
	| "DELETE_ATTR"
	| "LOAD_SUBSCR"
	| "STORE_SUBSCR"
	| "DELETE_SUBSCR"
	-- Collection construction
	| "BUILD_TUPLE"
	| "BUILD_LIST"
	| "BUILD_SET"
	| "BUILD_MAP"

-- Opcode information
export type OpcodeInfo = {
	name: Opcode,
	arg: boolean, -- Does this opcode take an argument?
	doc: string, -- Documentation
}

-- TODO: Implement opcode definitions and utilities in Phase 4

return Opcodes
