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
	-- Function-specific fields
	name: string?, -- Function name (for function code objects)
	argcount: number?, -- Number of positional arguments
	kwonlyargcount: number?, -- Number of keyword-only arguments
}

-- Internal compiler emitter state
type CompilerState = {
	code: CodeObject,
	constIndex: { [string]: number }, -- Keyed by serialized constant value
	nameIndex: { [string]: number },
	loopStack: { { startLabel: number, endLabel: number } }, -- For break/continue
	labelCounter: number, -- For generating unique labels
}

-- Forward declarations
local compileStmt: (st: CompilerState, node: any) -> ()
local compileFunctionDef: (st: CompilerState, node: any) -> ()

-- Initialize forward declarations
compileStmt = nil :: any
compileFunctionDef = nil :: any

local function newState(): CompilerState
	return {
		code = { constants = {}, names = {}, varnames = {}, bytecode = {}, firstlineno = nil, lnotab = nil },
		constIndex = {},
		nameIndex = {},
		loopStack = {},
		labelCounter = 0,
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

	-- Handle nil specially since table.insert(t, nil) doesn't work
	local storedValue = value
	if value == nil then
		storedValue = { __nil = true } -- Sentinel for nil
	end

	table.insert(st.code.constants, storedValue)
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

-- Label and jump management
local function _getNextLabel(st: CompilerState): number
	st.labelCounter = st.labelCounter + 1
	return st.labelCounter
end

local function getCurrentAddress(st: CompilerState): number
	return #st.code.bytecode
end

local function patchJump(st: CompilerState, jumpAddr: number, targetAddr: number?)
	local target = targetAddr or getCurrentAddress(st)
	local instruction = st.code.bytecode[jumpAddr + 1] -- +1 for 1-based indexing
	if instruction then
		instruction.arg = target + 1 -- Convert to 1-based index for VM
	end
end

local function enterLoop(st: CompilerState, startLabel: number, endLabel: number)
	table.insert(st.loopStack, { startLabel = startLabel, endLabel = endLabel })
end

local function exitLoop(st: CompilerState)
	table.remove(st.loopStack)
end

local function getCurrentLoop(st: CompilerState): { startLabel: number, endLabel: number }?
	return st.loopStack[#st.loopStack]
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
	elseif t == "Compare" then
		-- Compile comparison: left op right
		compileExpr(st, node.left)
		-- For now, only handle single comparison (not chained)
		if #node.ops == 1 and #node.comparators == 1 then
			compileExpr(st, node.comparators[1])
			local op = node.ops[1]
			local opcode: number
			if op == "Lt" then
				opcode = 0 -- <
			elseif op == "LtE" then
				opcode = 1 -- <=
			elseif op == "Eq" then
				opcode = 2 -- ==
			elseif op == "NotEq" then
				opcode = 3 -- !=
			elseif op == "Gt" then
				opcode = 4 -- >
			elseif op == "GtE" then
				opcode = 5 -- >=
			else
				error("Unsupported comparison op: " .. tostring(op))
			end
			emit(st, "COMPARE_OP", opcode, node.lineno)
		else
			error("Chained comparisons not yet supported")
		end
	elseif t == "Call" then
		-- Compile function call: func(args)
		compileExpr(st, node.func) -- Function object on stack

		-- Compile arguments
		for _, arg in ipairs(node.args) do
			compileExpr(st, arg)
		end

		-- Emit CALL_FUNCTION with argument count
		local arg_count = #node.args
		emit(st, "CALL_FUNCTION", arg_count, node.lineno)
	elseif t == "List" then
		-- Compile list literal: [1, 2, 3]
		-- Push all elements onto stack
		for _, elt in ipairs(node.elts) do
			compileExpr(st, elt)
		end
		-- Build list from stack elements
		emit(st, "BUILD_LIST", #node.elts, node.lineno)
	else
		error("Unsupported expression node type: " .. tostring(t))
	end
end

-- Statement compilation
compileStmt = function(st: CompilerState, node: any)
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
	elseif node.type == "If" then
		compileExpr(st, node.test)
		local jumpIfFalse = getCurrentAddress(st)
		emit(st, "POP_JUMP_IF_FALSE", 0, node.lineno) -- Will be patched

		-- Compile if body
		for _, stmt in ipairs(node.body) do
			compileStmt(st, stmt)
		end

		if #node.orelse > 0 then
			local jumpToEnd = getCurrentAddress(st)
			emit(st, "JUMP_FORWARD", 0, node.lineno) -- Will be patched
			patchJump(st, jumpIfFalse, getCurrentAddress(st))

			-- Compile else body
			for _, stmt in ipairs(node.orelse) do
				compileStmt(st, stmt)
			end

			patchJump(st, jumpToEnd, getCurrentAddress(st))
		else
			patchJump(st, jumpIfFalse, getCurrentAddress(st))
		end
	elseif node.type == "While" then
		-- Emit SETUP_LOOP to set up the loop block
		local setupLoop = getCurrentAddress(st)
		emit(st, "SETUP_LOOP", 0, node.lineno) -- Will be patched with end offset
		
		local loopStart = getCurrentAddress(st)
		compileExpr(st, node.test)
		local jumpIfFalse = getCurrentAddress(st)
		emit(st, "POP_JUMP_IF_FALSE", 0, node.lineno) -- Will be patched to end

		-- Setup loop for break/continue
		enterLoop(st, loopStart, jumpIfFalse) -- endLabel will be patched later

		-- Compile loop body
		for _, stmt in ipairs(node.body) do
			compileStmt(st, stmt)
		end

		-- Jump back to start (calculate relative offset)
		local currentAddr = getCurrentAddress(st)
		local relativeOffset = loopStart - currentAddr - 1 -- -1 because advance will add 1
		emit(st, "JUMP_FORWARD", relativeOffset, node.lineno)

		-- Mark the end position for the loop
		local loopEnd = getCurrentAddress(st)
		
		-- Patch the end jump
		patchJump(st, jumpIfFalse, loopEnd)
		
		-- Compile else clause if present
		if #node.orelse > 0 then
			for _, stmt in ipairs(node.orelse) do
				compileStmt(st, stmt)
			end
		end

		-- Pop the loop block and patch SETUP_LOOP with the end address (should point to POP_BLOCK)
		local blockEnd = getCurrentAddress(st)
		emit(st, "POP_BLOCK", nil, node.lineno)
		patchJump(st, setupLoop, blockEnd) -- Point to POP_BLOCK instruction

		exitLoop(st)
	elseif node.type == "For" then
		-- Python for loop using proper iteration protocol
		-- 1. Compile the iterable expression
		compileExpr(st, node.iter)

		-- 2. Get iterator from iterable
		emit(st, "GET_ITER", nil, node.lineno)

		-- 3. Emit SETUP_LOOP to set up the loop block
		local setupLoop = getCurrentAddress(st)
		emit(st, "SETUP_LOOP", 0, node.lineno) -- Will be patched with end offset

		-- 4. Mark loop start
		local loopStart = getCurrentAddress(st)

		-- 5. Try to get next value from iterator
		local forIterJump = getCurrentAddress(st)
		emit(st, "FOR_ITER", 0, node.lineno) -- Will be patched to end

		-- 6. Setup loop for break/continue
		enterLoop(st, loopStart, forIterJump)

		-- 7. Store the iteration value in the target variable
		if node.target.type == "Name" then
			node.target.ctx = "Store"
			compileName(st, node.target)
		else
			error("Complex assignment targets not supported yet", 2)
		end

		-- 8. Compile loop body
		for _, stmt in ipairs(node.body) do
			compileStmt(st, stmt)
		end

		-- 9. Jump back to FOR_ITER
		local currentAddr = getCurrentAddress(st)
		local relativeOffset = loopStart - currentAddr - 1
		emit(st, "JUMP_FORWARD", relativeOffset, node.lineno)

		-- 10. Mark the end position for the loop (before patching)
		local loopEnd = getCurrentAddress(st)
		
		-- 11. Patch the FOR_ITER jump to exit the loop
		patchJump(st, forIterJump, loopEnd)
		
		-- 12. Compile else clause if present
		if #node.orelse > 0 then
			for _, stmt in ipairs(node.orelse) do
				compileStmt(st, stmt)
			end
		end
		
		-- Pop the loop block and patch SETUP_LOOP with the end address (should point to POP_BLOCK)
		local blockEnd = getCurrentAddress(st)
		emit(st, "POP_BLOCK", nil, node.lineno)
		patchJump(st, setupLoop, blockEnd) -- Point to POP_BLOCK instruction

		exitLoop(st)
	elseif node.type == "Break" then
		local loop = getCurrentLoop(st)
		if not loop then
			error("'break' outside loop", 2)
		end
		emit(st, "BREAK_LOOP", nil, node.lineno)
	elseif node.type == "Continue" then
		local loop = getCurrentLoop(st)
		if not loop then
			error("'continue' not properly in loop", 2)
		end
		emit(st, "CONTINUE_LOOP", loop.startLabel, node.lineno)
	elseif node.type == "Pass" then
		-- Pass statement does nothing
		-- No bytecode emitted
	elseif node.type == "FunctionDef" then
		-- Compile function definition
		compileFunctionDef(st, node)
	else
		error("Unsupported statement type: " .. tostring(node.type))
	end
end

-- Compile function definition
compileFunctionDef = function(st: CompilerState, node: any)
	-- Extract function details
	local funcName = node.name
	local args = node.args
	local body = node.body

	-- Create a new compiler state for the function
	local funcState = newState()
	funcState.code.name = funcName
	funcState.code.firstlineno = node.lineno

	-- Count arguments
	local argcount = 0
	local varnames: { string } = {}

	-- Process function arguments
	if args and args.args then
		for _, arg in ipairs(args.args) do
			argcount = argcount + 1
			table.insert(varnames, arg.arg or arg.name or ("arg" .. argcount))
		end
	end

	funcState.code.argcount = argcount
	funcState.code.varnames = varnames

	-- Compile function body
	for _, stmt in ipairs(body) do
		compileStmt(funcState, stmt)
	end

	-- Add implicit return None if no explicit return
	local idxNone = addConst(funcState, nil)
	emit(funcState, "LOAD_CONST", idxNone, node.lineno)
	emit(funcState, "RETURN_VALUE", nil, node.lineno)

	-- Create the function object in the parent scope
	-- First, add the function code as a constant
	local funcCodeIdx = addConst(st, funcState.code)
	emit(st, "LOAD_CONST", funcCodeIdx, node.lineno)

	-- Add function defaults (simplified - no defaults for now)
	emit(st, "LOAD_CONST", addConst(st, 0), node.lineno) -- default count

	-- Create the function object
	emit(st, "MAKE_FUNCTION", 0, node.lineno) -- flags = 0 (no defaults, closure, etc.)

	-- Store the function in the current scope
	local nameIdx = addName(st, funcName)
	emit(st, "STORE_NAME", nameIdx, node.lineno)
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
