--!strict
-- PyLua Compiler - AST to Bytecode compilation
-- Phase 4 - Will implement AST to bytecode transformation

local Compiler = {}

local instructions = require("./bytecode/instructions")
local opcodes = require("./bytecode/opcodes")
local nodes = require("./ast/nodes")

type Instruction = instructions.Instruction
type Opcode = opcodes.Opcode

-- CodeObject mirrors simplified CPython code object subset
export type CodeObject = {
	constants: { any }, -- Constant pool (numbers, strings, nested code objects later)
	names: { string }, -- Names referenced (LOAD_NAME / STORE_NAME indices)
	varnames: { string }, -- Local variable names (future LOAD_FAST)
	bytecode: { Instruction }, -- Ordered instruction list
	firstlineno: number?,
	lnotab: { number }?, -- Placeholder for line number table (not yet used)
}

-- Internal compiler emitter state
type CompilerState = {
	code: CodeObject,
	constIndex: { [string]: number }, -- Keyed by serialized constant value
	nameIndex: { [string]: number },
}

local function newState(): CompilerState
	return {
		code = { constants = {}, names = {}, varnames = {}, bytecode = {}, firstlineno = nil, lnotab = nil },
		constIndex = {},
		nameIndex = {},
	}
end

local function serializeConst(v: any): string
	local t = typeof(v)
	if t == "nil" then
		return "N"
	elseif t == "number" then
		return "F" .. tostring(v)
	elseif t == "boolean" then
		return v and "B1" or "B0"
	elseif t == "string" then
		return "S" .. v
	else
		-- Fallback (tables etc) - use tostring pointer; collisions acceptable for now
		return "O" .. tostring(v)
	end
end

local function addConst(st: CompilerState, value: any): number
	local key = serializeConst(value)
	local idx = st.constIndex[key]
	if idx then
		return idx
	end
	table.insert(st.code.constants, value)
	local newIdx = #st.code.constants - 1 -- Use zero-based indices like CPython
	st.constIndex[key] = newIdx
	return newIdx
end

local function addName(st: CompilerState, name: string): number
	local idx = st.nameIndex[name]
	if idx then
		return idx
	end
	table.insert(st.code.names, name)
	local newIdx = #st.code.names - 1
	st.nameIndex[name] = newIdx
	return newIdx
end

local function emit(st: CompilerState, op: Opcode, arg: number?, lineno: number?)
	local inst = instructions.make(op, arg, lineno)
	st.code.bytecode[#st.code.bytecode + 1] = inst
end

-- Expression compilation
local compileExpr

local function compileName(st: CompilerState, node: any)
	if node.ctx == "Load" then
		local idx = addName(st, node.id)
		emit(st, "LOAD_NAME", idx, node.lineno)
	elseif node.ctx == "Store" then
		local idx = addName(st, node.id)
		emit(st, "STORE_NAME", idx, node.lineno)
	else
		error("Unsupported Name ctx: " .. tostring(node.ctx))
	end
end

local BINOP_TO_OPCODE: { [nodes.BinOpType]: Opcode } = {
	Add = "BINARY_ADD",
	Sub = "BINARY_SUBTRACT",
	Mult = "BINARY_MULTIPLY",
	Div = "BINARY_DIVIDE",
	Mod = "BINARY_MODULO",
	Pow = "BINARY_POWER",
	LShift = "BINARY_LSHIFT",
	RShift = "BINARY_RSHIFT",
	BitOr = "BINARY_OR",
	BitXor = "BINARY_XOR",
	BitAnd = "BINARY_AND",
	-- MatMult, FloorDiv not yet mapped
}

compileExpr = function(st: CompilerState, node: any)
	local t = node.type
	if t == "Constant" then
		local idx = addConst(st, node.value)
		emit(st, "LOAD_CONST", idx, node.lineno)
	elseif t == "Name" then
		compileName(st, node)
	elseif t == "BinOp" then
		compileExpr(st, node.left)
		compileExpr(st, node.right)
		local op = BINOP_TO_OPCODE[node.op]
		if not op then
			error("Unsupported binary op: " .. tostring(node.op))
		end
		emit(st, (op :: any) :: Opcode, nil, node.lineno)
	elseif t == "UnaryOp" then
		compileExpr(st, node.operand)
		if node.op == "UAdd" then
			emit(st, "UNARY_POSITIVE", nil, node.lineno)
		elseif node.op == "USub" then
			emit(st, "UNARY_NEGATIVE", nil, node.lineno)
		elseif node.op == "Not" then
			emit(st, "UNARY_NOT", nil, node.lineno)
		elseif node.op == "Invert" then
			emit(st, "UNARY_INVERT", nil, node.lineno)
		else
			error("Unsupported unary op: " .. tostring(node.op))
		end
	else
		error("Unsupported expression node type: " .. tostring(t))
	end
end

-- Statement compilation
local function compileStmt(st: CompilerState, node: any)
	if node.type == "Expr" then
		compileExpr(st, node.value)
		-- POP_TOP to discard value of expression statements
		emit(st, "POP_TOP", nil, node.lineno)
	elseif node.type == "Assign" then
		-- For now only single target supported
		compileExpr(st, node.value)
		local target = node.targets[1]
		if not target then
			error("Assign without target")
		end
		if target.type == "Name" then
			target.ctx = "Store"
			compileName(st, target)
		else
			error("Unsupported assignment target type: " .. tostring(target.type))
		end
	elseif node.type == "Return" then
		if node.value then
			compileExpr(st, node.value)
		else
			local idx = addConst(st, nil)
			emit(st, "LOAD_CONST", idx, node.lineno)
		end
		emit(st, "RETURN_VALUE", nil, node.lineno)
	else
		error("Unsupported statement type: " .. tostring(node.type))
	end
end

local function compileModule(ast: any): CodeObject
	local st = newState()
	st.code.firstlineno = ast.lineno
	for _, stmt in ipairs(ast.body) do
		compileStmt(st, stmt)
	end
	-- Implicit return None at module end (push None then RETURN_VALUE)
	local idxNone = addConst(st, nil)
	emit(st, "LOAD_CONST", idxNone, ast.lineno)
	emit(st, "RETURN_VALUE", nil, ast.lineno)
	return st.code
end

-- Public compile entry (accept Module AST or expression for REPL style)
function Compiler.compile(ast: any): CodeObject
	if ast.type == "Module" then
		return compileModule(ast)
	elseif ast.type == "Expr" or ast.type == "BinOp" or ast.type == "Constant" then
		-- Wrap expression into fake module returning value
		local fakeModule = {
			type = "Module",
			body = { { type = "Return", value = ast, lineno = ast.lineno, col_offset = ast.col_offset } },
			lineno = ast.lineno,
			col_offset = ast.col_offset,
		}
		return compileModule(fakeModule)
	else
		error("Unsupported root AST for compile: " .. tostring(ast.type))
	end
end

return Compiler
