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
	| "BINARY_FLOOR_DIVIDE"
	| "BINARY_MATRIX_MULTIPLY"
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
	| "SETUP_LOOP"
	| "SETUP_EXCEPT"
	| "SETUP_FINALLY"
	| "POP_BLOCK"
	| "BREAK_LOOP"
	| "CONTINUE_LOOP"
	| "BEGIN_FINALLY"
	| "END_FINALLY"
	-- Iteration
	| "GET_ITER"
	| "FOR_ITER"
	-- Unpacking
	| "UNPACK_SEQUENCE"
	-- Function calls
	| "MAKE_FUNCTION"
	| "CALL_FUNCTION"
	| "YIELD_VALUE"
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
	| "BUILD_MAP_UNPACK"
	| "BUILD_CLASS"
	-- Imports
	| "IMPORT_NAME"
	| "IMPORT_FROM"
	| "IMPORT_STAR"

-- Opcode information
export type OpcodeInfo = {
	name: Opcode,
	arg: boolean, -- Does this opcode take an argument?
	doc: string, -- Documentation
}

-- Internal opcode metadata table
local OPCODE_INFO: { [Opcode]: OpcodeInfo } = {
	-- Stack manipulation
	POP_TOP = { name = "POP_TOP", arg = false, doc = "Pop and discard top of stack" },
	ROT_TWO = { name = "ROT_TWO", arg = false, doc = "Swap two top-most stack items" },
	ROT_THREE = { name = "ROT_THREE", arg = false, doc = "Rotate three top-most stack items" },
	DUP_TOP = { name = "DUP_TOP", arg = false, doc = "Duplicate top stack item" },

	-- Variables / names / locals / globals
	LOAD_CONST = { name = "LOAD_CONST", arg = true, doc = "Push constant at index" },
	LOAD_NAME = { name = "LOAD_NAME", arg = true, doc = "Load name (namespace resolved)" },
	STORE_NAME = { name = "STORE_NAME", arg = true, doc = "Store TOS into name" },
	DELETE_NAME = { name = "DELETE_NAME", arg = true, doc = "Delete name" },
	LOAD_FAST = { name = "LOAD_FAST", arg = true, doc = "Load fast local by index" },
	STORE_FAST = { name = "STORE_FAST", arg = true, doc = "Store into fast local by index" },
	DELETE_FAST = { name = "DELETE_FAST", arg = true, doc = "Delete fast local" },
	LOAD_GLOBAL = { name = "LOAD_GLOBAL", arg = true, doc = "Load global name" },
	STORE_GLOBAL = { name = "STORE_GLOBAL", arg = true, doc = "Store global name" },
	DELETE_GLOBAL = { name = "DELETE_GLOBAL", arg = true, doc = "Delete global name" },

	-- Binary operations
	BINARY_ADD = { name = "BINARY_ADD", arg = false, doc = "TOS = TOS1 + TOS" },
	BINARY_SUBTRACT = { name = "BINARY_SUBTRACT", arg = false, doc = "TOS = TOS1 - TOS" },
	BINARY_MULTIPLY = { name = "BINARY_MULTIPLY", arg = false, doc = "TOS = TOS1 * TOS" },
	BINARY_DIVIDE = { name = "BINARY_DIVIDE", arg = false, doc = "TOS = TOS1 / TOS" },
	BINARY_MODULO = { name = "BINARY_MODULO", arg = false, doc = "TOS = TOS1 % TOS" },
	BINARY_POWER = { name = "BINARY_POWER", arg = false, doc = "TOS = TOS1 ** TOS" },
	BINARY_LSHIFT = { name = "BINARY_LSHIFT", arg = false, doc = "TOS = TOS1 << TOS" },
	BINARY_RSHIFT = { name = "BINARY_RSHIFT", arg = false, doc = "TOS = TOS1 >> TOS" },
	BINARY_OR = { name = "BINARY_OR", arg = false, doc = "TOS = TOS1 | TOS" },
	BINARY_XOR = { name = "BINARY_XOR", arg = false, doc = "TOS = TOS1 ^ TOS" },
	BINARY_AND = { name = "BINARY_AND", arg = false, doc = "TOS = TOS1 & TOS" },
	BINARY_FLOOR_DIVIDE = { name = "BINARY_FLOOR_DIVIDE", arg = false, doc = "TOS = TOS1 // TOS" },
	BINARY_MATRIX_MULTIPLY = { name = "BINARY_MATRIX_MULTIPLY", arg = false, doc = "TOS = TOS1 @ TOS" },

	-- Unary operations
	UNARY_POSITIVE = { name = "UNARY_POSITIVE", arg = false, doc = "+TOS" },
	UNARY_NEGATIVE = { name = "UNARY_NEGATIVE", arg = false, doc = "-TOS" },
	UNARY_NOT = { name = "UNARY_NOT", arg = false, doc = "not TOS" },
	UNARY_INVERT = { name = "UNARY_INVERT", arg = false, doc = "~TOS" },

	-- Comparison
	COMPARE_OP = { name = "COMPARE_OP", arg = true, doc = "Compare operation code" },

	-- Control flow / jumps (arg = target offset or delta TBD)
	JUMP_FORWARD = { name = "JUMP_FORWARD", arg = true, doc = "Jump forward by delta" },
	JUMP_IF_TRUE_OR_POP = { name = "JUMP_IF_TRUE_OR_POP", arg = true, doc = "Jump if TOS true else pop" },
	JUMP_IF_FALSE_OR_POP = { name = "JUMP_IF_FALSE_OR_POP", arg = true, doc = "Jump if TOS false else pop" },
	POP_JUMP_IF_TRUE = { name = "POP_JUMP_IF_TRUE", arg = true, doc = "Pop and jump if true" },
	POP_JUMP_IF_FALSE = { name = "POP_JUMP_IF_FALSE", arg = true, doc = "Pop and jump if false" },
	SETUP_LOOP = { name = "SETUP_LOOP", arg = true, doc = "Setup loop with end offset" },
	SETUP_EXCEPT = { name = "SETUP_EXCEPT", arg = true, doc = "Setup exception handler" },
	SETUP_FINALLY = { name = "SETUP_FINALLY", arg = true, doc = "Setup finally handler" },
	POP_BLOCK = { name = "POP_BLOCK", arg = false, doc = "Pop a block from block stack" },
	BREAK_LOOP = { name = "BREAK_LOOP", arg = false, doc = "Break out of current loop" },
	CONTINUE_LOOP = { name = "CONTINUE_LOOP", arg = true, doc = "Continue to loop start" },
	BEGIN_FINALLY = { name = "BEGIN_FINALLY", arg = false, doc = "Enter finally block (normal exit)" },
	END_FINALLY = { name = "END_FINALLY", arg = false, doc = "Complete finally block action" },

	-- Iteration
	GET_ITER = { name = "GET_ITER", arg = false, doc = "Get iterator from iterable" },
	FOR_ITER = { name = "FOR_ITER", arg = true, doc = "Iterate over iterator or jump" },

	-- Unpacking
	UNPACK_SEQUENCE = { name = "UNPACK_SEQUENCE", arg = true, doc = "Unpack sequence into N values" },

	-- Function calls
	MAKE_FUNCTION = { name = "MAKE_FUNCTION", arg = true, doc = "Create function object" },
	CALL_FUNCTION = { name = "CALL_FUNCTION", arg = true, doc = "Call with positional arg count" },
	YIELD_VALUE = { name = "YIELD_VALUE", arg = false, doc = "Yield from generator" },
	RETURN_VALUE = { name = "RETURN_VALUE", arg = false, doc = "Return TOS" },

	-- Object / attribute / subscripting
	LOAD_ATTR = { name = "LOAD_ATTR", arg = true, doc = "Load attribute by name index" },
	STORE_ATTR = { name = "STORE_ATTR", arg = true, doc = "Store attribute by name index" },
	DELETE_ATTR = { name = "DELETE_ATTR", arg = true, doc = "Delete attribute by name index" },
	LOAD_SUBSCR = { name = "LOAD_SUBSCR", arg = false, doc = "TOS = TOS1[TOS]" },
	STORE_SUBSCR = { name = "STORE_SUBSCR", arg = false, doc = "TOS1[TOS] = TOS2" },
	DELETE_SUBSCR = { name = "DELETE_SUBSCR", arg = false, doc = "del TOS1[TOS]" },

	-- Collection construction (arg = element count except BUILD_MAP uses pair count)
	BUILD_TUPLE = { name = "BUILD_TUPLE", arg = true, doc = "Build tuple from N stack items" },
	BUILD_LIST = { name = "BUILD_LIST", arg = true, doc = "Build list from N stack items" },
	BUILD_SET = { name = "BUILD_SET", arg = true, doc = "Build set from N stack items" },
	BUILD_MAP = { name = "BUILD_MAP", arg = true, doc = "Build map from 2*N stack items" },
	BUILD_MAP_UNPACK = { name = "BUILD_MAP_UNPACK", arg = true, doc = "Merge N dicts on stack into one" },
	BUILD_CLASS = { name = "BUILD_CLASS", arg = true, doc = "Construct a Python class from stack values" },

	-- Imports
	IMPORT_NAME = { name = "IMPORT_NAME", arg = true, doc = "Import module by name index" },
	IMPORT_FROM = { name = "IMPORT_FROM", arg = true, doc = "Import symbol from module by name index" },
	IMPORT_STAR = { name = "IMPORT_STAR", arg = false, doc = "Import all symbols from module" },
}

-- Public API
function Opcodes.getInfo(op: Opcode): OpcodeInfo
	local info = OPCODE_INFO[op]
	if not info then
		error("Unknown opcode: " .. tostring(op), 2)
	end
	return info
end

function Opcodes.requiresArg(op: Opcode): boolean
	return Opcodes.getInfo(op).arg
end

function Opcodes.list(): { Opcode }
	local arr: { Opcode } = {}
	for name, _ in pairs(OPCODE_INFO :: any) do
		arr[#arr + 1] = (name :: any) :: Opcode
	end
	table.sort(arr, function(a: string, b: string)
		return a < b
	end)
	return arr
end

function Opcodes.describe(): { [string]: string }
	local out: { [string]: string } = {}
	for _, op in ipairs(Opcodes.list()) do
		local inf = OPCODE_INFO[op :: Opcode]
		out[op] = (inf.arg and "(arg) " or "") .. inf.doc
	end
	return out
end

return Opcodes
