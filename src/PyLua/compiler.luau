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
	tempNameCounter: number,
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
		tempNameCounter = 0,
	}
end

local function newTempName(st: CompilerState, prefix: string): string
	st.tempNameCounter += 1
	return prefix .. tostring(st.tempNameCounter)
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

local function deepCopy(value: any): any
	if type(value) ~= "table" then
		return value
	end
	local result = {}
	for k, v in pairs(value) do
		result[k] = deepCopy(v)
	end
	return result
end

local function cloneExpr(expr: any): any
	return deepCopy(expr)
end

local function setStoreContext(node: any)
	local t = node.type
	if t == "Name" or t == "Attribute" or t == "Subscript" then
		node.ctx = "Store"
	elseif t == "Tuple" or t == "List" then
		node.ctx = "Store"
		for _, elt in ipairs(node.elts) do
			setStoreContext(elt)
		end
	elseif t == "Starred" then
		node.ctx = "Store"
		setStoreContext(node.value)
	end
end

local function makeNameExpr(id: string, ctx: nodes.ExprContext, lineno: number, col: number)
	return { type = "Name", id = id, ctx = ctx, lineno = lineno, col_offset = col }
end

local function buildListCompStatements(node: nodes.ListComp, resultName: string): { any }
	local stmts: { any } = {}
	local listInit = {
		type = "Assign",
		targets = {
			{
				type = "Name",
				id = resultName,
				ctx = "Store",
				lineno = node.lineno,
				col_offset = node.col_offset,
			},
		},
		value = { type = "List", elts = {}, ctx = "Load", lineno = node.lineno, col_offset = node.col_offset },
		lineno = node.lineno,
		col_offset = node.col_offset,
	}
	stmts[#stmts + 1] = listInit

	local function appendCall(): any
		local valueExpr = cloneExpr(node.elt)
		local attr = {
			type = "Attribute",
			value = makeNameExpr(resultName, "Load", node.lineno, node.col_offset),
			attr = "append",
			ctx = "Load",
			lineno = node.lineno,
			col_offset = node.col_offset,
		}
		return {
			type = "Call",
			func = attr,
			args = { valueExpr },
			keywords = {},
			lineno = valueExpr.lineno or node.lineno,
			col_offset = valueExpr.col_offset or node.col_offset,
		}
	end

	local function wrapIfs(ifs: { any }, inner: { any }): { any }
		local body = inner
		for i = #ifs, 1, -1 do
			local cond = cloneExpr(ifs[i])
			body = {
				{
					type = "If",
					test = cond,
					body = body,
					orelse = {},
					lineno = cond.lineno or node.lineno,
					col_offset = cond.col_offset or node.col_offset,
				},
			}
		end
		return body
	end

	local function buildGenerator(index: number): { any }
		local gen = node.generators[index]
		local targetClone = cloneExpr(gen.target)
		setStoreContext(targetClone)
		local iterClone = cloneExpr(gen.iter)
		local innerBody: { any }
		if index == #node.generators then
			local callExpr = appendCall()
			innerBody = {
				{ type = "Expr", value = callExpr, lineno = callExpr.lineno, col_offset = callExpr.col_offset },
			}
		else
			innerBody = buildGenerator(index + 1)
		end
		if gen.ifs and #gen.ifs > 0 then
			innerBody = wrapIfs(gen.ifs, innerBody)
		end
		local forNode = {
			type = "For",
			target = targetClone,
			iter = iterClone,
			body = innerBody,
			orelse = {},
			lineno = targetClone.lineno or node.lineno,
			col_offset = targetClone.col_offset or node.col_offset,
		}
		return { forNode }
	end

	local loopStmts = buildGenerator(1)
	for _, stmt in ipairs(loopStmts) do
		stmts[#stmts + 1] = stmt
	end

	stmts[#stmts + 1] = {
		type = "Return",
		value = makeNameExpr(resultName, "Load", node.lineno, node.col_offset),
		lineno = node.lineno,
		col_offset = node.col_offset,
	}

	return stmts
end

local function compileListCompExpr(st: CompilerState, node: nodes.ListComp)
	local compState = newState()
	compState.code.name = "<listcomp>"
	compState.code.firstlineno = node.lineno
	compState.code.argcount = 0
	compState.code.kwonlyargcount = 0
	compState.code.varnames = {}

	local resultName = newTempName(compState, "__listcomp_result_")
	local stmts = buildListCompStatements(node, resultName)
	for _, stmt in ipairs(stmts) do
		compileStmt(compState, stmt)
	end

	local codeIdx = addConst(st, compState.code)
	local zeroIdx = addConst(st, 0)
	emit(st, "LOAD_CONST", codeIdx, node.lineno)
	emit(st, "LOAD_CONST", zeroIdx, node.lineno)
	emit(st, "MAKE_FUNCTION", 0, node.lineno)
	emit(st, "CALL_FUNCTION", 0, node.lineno)
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
		local opcode = instruction.opcode
		if opcode == "JUMP_FORWARD" then
			-- TOOK ME 4 HOURS TO FIND I DID NOT IMPLEMENT THIS
			-- Why did I ignore JUMP_FORWARD instructions in patching???

			-- Relative jump; calculate offset from next instruction
			-- JUMP_FORWARD arg is number of instructions to skip
			local targetIndex = target + 1
			instruction.arg = targetIndex - (jumpAddr + 2)
		else
			instruction.arg = target + 1 -- Convert to 1-based index for absolute jump targets
		end
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

local function withContext(node: any, ctx: nodes.ExprContext, fn: () -> ())
	local prev = node.ctx
	node.ctx = ctx
	fn()
	node.ctx = prev
end

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

-- Compile an assignment target (handles Name, Tuple, etc.)
local function compileAssignmentTarget(st: CompilerState, target: any)
	if target.type == "Name" then
		target.ctx = "Store"
		compileName(st, target)
	elseif target.type == "Tuple" then
		-- For tuple targets, we need to unpack the value on TOS
		-- Set context to Store for consistency
		target.ctx = "Store"
		
		-- Emit UNPACK_SEQUENCE with the count of elements
		local count = #target.elts
		emit(st, "UNPACK_SEQUENCE", count, target.lineno)
		
		-- Now compile each element as a store target
		-- UNPACK_SEQUENCE pushes values in reverse order, so we store them in forward order
		for _, elt in ipairs(target.elts) do
			compileAssignmentTarget(st, elt)
		end
	elseif target.type == "Attribute" then
		-- For attribute assignment: obj.attr = value
		-- TOS is value, compile the object
		compileExpr(st, target.value)
		local idx = addName(st, target.attr)
		emit(st, "STORE_ATTR", idx, target.lineno)
	elseif target.type == "Subscript" then
		-- For subscript assignment: obj[key] = value
		-- TOS is value, need obj and key
		compileExpr(st, target.value)
		compileExpr(st, target.slice)
		emit(st, "STORE_SUBSCR", nil, target.lineno)
	else
		error("Unsupported assignment target type: " .. tostring(target.type))
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
	FloorDiv = "BINARY_FLOOR_DIVIDE",
	MatMult = "BINARY_MATRIX_MULTIPLY",
}

local COMPARE_TO_OPCODE: { [nodes.CmpOp]: number } = {
	Lt = 0,
	LtE = 1,
	Eq = 2,
	NotEq = 3,
	Gt = 4,
	GtE = 5,
	Is = 6,
	IsNot = 7,
	In = 8,
	NotIn = 9,
}

local function compileLoadTarget(st: CompilerState, target: any)
	if target.type == "Name" then
		withContext(target, "Load", function()
			compileName(st, target)
		end)
	elseif target.type == "Attribute" then
		compileExpr(st, target.value)
		local idx = addName(st, target.attr)
		emit(st, "LOAD_ATTR", idx, target.lineno)
	elseif target.type == "Subscript" then
		compileExpr(st, target.value)
		compileExpr(st, target.slice)
		emit(st, "LOAD_SUBSCR", nil, target.lineno)
	else
		error("Unsupported load target type: " .. tostring(target.type))
	end
end

local function compileStoreTarget(st: CompilerState, target: any)
	if target.type == "Name" then
		withContext(target, "Store", function()
			compileName(st, target)
		end)
	elseif target.type == "Attribute" then
		compileExpr(st, target.value)
		emit(st, "ROT_TWO", nil, target.lineno)
		local idx = addName(st, target.attr)
		emit(st, "STORE_ATTR", idx, target.lineno)
	elseif target.type == "Subscript" then
		compileExpr(st, target.value)
		emit(st, "ROT_TWO", nil, target.lineno)
		compileExpr(st, target.slice)
		emit(st, "ROT_TWO", nil, target.lineno)
		emit(st, "STORE_SUBSCR", nil, target.lineno)
	else
		error("Unsupported store target type: " .. tostring(target.type))
	end
end

compileExpr = function(st: CompilerState, node: any)
	local t = node.type
	if t == "Constant" then
		-- Special-case bytes literals (marked by parser kind)
		if node.kind == "bytes" then
			-- We cannot precreate PyObjects in constant pool reliably; store a tagged table to be materialized in VM
			local tagged = { __bytes_literal = true, value = node.value }
			local idx = addConst(st, tagged)
			emit(st, "LOAD_CONST", idx, node.lineno)
		else
			local idx = addConst(st, node.value)
			emit(st, "LOAD_CONST", idx, node.lineno)
		end
	elseif t == "Name" then
		compileName(st, node)
	elseif t == "Attribute" then
		compileExpr(st, node.value)
		local idx = addName(st, node.attr)
		emit(st, "LOAD_ATTR", idx, node.lineno)
	elseif t == "Subscript" then
		compileExpr(st, node.value)
		compileExpr(st, node.slice)
		emit(st, "LOAD_SUBSCR", nil, node.lineno)
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
		local opCount = #node.ops
		local comparatorCount = #node.comparators
		if opCount ~= comparatorCount or opCount == 0 then
			error("Invalid comparison operands")
		end

		compileExpr(st, node.left)
		local falseJumpFixups: { number } = {}

		for index, op in ipairs(node.ops) do
			local comparator = node.comparators[index]
			local isLast = index == opCount
			local lineno = (comparator and comparator.lineno) or node.lineno

			compileExpr(st, comparator)
			if not isLast then
				emit(st, "DUP_TOP", nil, lineno)
				emit(st, "ROT_THREE", nil, lineno)
			end

			local opcode = COMPARE_TO_OPCODE[op]
			if opcode == nil then
				error("Unsupported comparison op: " .. tostring(op))
			end
			emit(st, "COMPARE_OP", opcode, lineno)

			if not isLast then
				local jumpAddr = getCurrentAddress(st)
				emit(st, "JUMP_IF_FALSE_OR_POP", 0, lineno)
				falseJumpFixups[#falseJumpFixups + 1] = jumpAddr
			end
		end

		if #falseJumpFixups > 0 then
			local jumpPastCleanup = getCurrentAddress(st)
			emit(st, "JUMP_FORWARD", 0, node.lineno)

			local cleanupAddr = getCurrentAddress(st)
			emit(st, "ROT_TWO", nil, node.lineno)
			emit(st, "POP_TOP", nil, node.lineno)
			local doneAddr = getCurrentAddress(st)

			for _, addr in ipairs(falseJumpFixups) do
				patchJump(st, addr, cleanupAddr)
			end
			patchJump(st, jumpPastCleanup, doneAddr)
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
	elseif t == "ListComp" then
		compileListCompExpr(st, node)
	elseif t == "List" then
		-- Compile list literal: [1, 2, 3]
		-- Push all elements onto stack
		for _, elt in ipairs(node.elts) do
			compileExpr(st, elt)
		end
		-- Build list from stack elements
		emit(st, "BUILD_LIST", #node.elts, node.lineno)
	elseif t == "Tuple" then
		for _, elt in ipairs(node.elts) do
			compileExpr(st, elt)
		end
		emit(st, "BUILD_TUPLE", #node.elts, node.lineno)
	elseif t == "Set" then
		for _, elt in ipairs(node.elts) do
			compileExpr(st, elt)
		end
		emit(st, "BUILD_SET", #node.elts, node.lineno)
	elseif t == "Dict" then
		local count = #node.keys
		local hasUnpack = false
		
		-- Check if we have any unpacking
		for i = 1, count do
			local key = node.keys[i]
			if key and key.type == "DictUnpack" then
				hasUnpack = true
				break
			end
		end
		
		if not hasUnpack then
			-- Simple dict without unpacking: {k1: v1, k2: v2}
			for i = 1, count do
				local key = node.keys[i]
				local value = node.values[i]
				compileExpr(st, key)
				compileExpr(st, value)
			end
			emit(st, "BUILD_MAP", count, node.lineno)
		else
			-- Dict with unpacking: {k1: v1, **d, k2: v2}
			-- Strategy: Build separate dicts and merge them
			-- Push each segment (regular pairs or unpacked dict) onto stack
			local segments = 0
			local currentPairs: { { key: any, value: any } } = {}
			
			local function flushCurrentPairs()
				if #currentPairs > 0 then
					-- Build a dict from accumulated key-value pairs
					for _, pair in ipairs(currentPairs) do
						compileExpr(st, pair.key)
						compileExpr(st, pair.value)
					end
					emit(st, "BUILD_MAP", #currentPairs, node.lineno)
					segments += 1
					currentPairs = {}
				end
			end
			
			for i = 1, count do
				local key = node.keys[i]
				local value = node.values[i]
				
				if key and key.type == "DictUnpack" then
					-- Flush any accumulated pairs first
					flushCurrentPairs()
					-- Push the dict to unpack onto stack
					compileExpr(st, value)
					segments += 1
				else
					-- Accumulate regular key-value pair
					table.insert(currentPairs, { key = key, value = value })
				end
			end
			
			-- Flush any remaining pairs
			flushCurrentPairs()
			
			-- Now merge all segments with BUILD_MAP_UNPACK
			if segments > 0 then
				emit(st, "BUILD_MAP_UNPACK", segments, node.lineno)
			else
				-- Edge case: empty dict
				emit(st, "BUILD_MAP", 0, node.lineno)
			end
		end
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
		compileExpr(st, node.value)
		local target = node.targets[1]
		if not target then
			error("Assign without target")
		end
		compileStoreTarget(st, target)
	elseif node.type == "AugAssign" then
		local target = node.target
		compileLoadTarget(st, target)
		compileExpr(st, node.value)
		local op = BINOP_TO_OPCODE[node.op]
		if not op then
			error("Unsupported augmented assignment operator: " .. tostring(node.op))
		end
		emit(st, (op :: any) :: Opcode, nil, node.lineno)
		compileStoreTarget(st, target)
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

		-- 7. Store the iteration value in the target variable(s)
		-- Now supports tuple unpacking: for x, y in items: ...
		compileAssignmentTarget(st, node.target)

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
	elseif ast.type == "Expr" or ast.type == "BinOp" or ast.type == "Constant" or ast.type == "ListComp" then
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
