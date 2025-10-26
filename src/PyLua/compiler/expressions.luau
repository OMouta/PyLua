local nodes = require("../ast/nodes")
local opcodes = require("../bytecode/opcodes")
local State = require("./state")

type CompilerState = State.CompilerState
type ExprContext = nodes.ExprContext
type ListComp = nodes.ListComp
type BinOpType = nodes.BinOpType
type CmpOp = nodes.CmpOp

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

local function makeNameExpr(id: string, ctx: ExprContext, lineno: number, col: number)
	return { type = "Name", id = id, ctx = ctx, lineno = lineno, col_offset = col }
end

local function buildListCompStatements(node: ListComp, resultName: string): { any }
	local stmts: { any } = {}

	stmts[#stmts + 1] = {
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
		return {
			{
				type = "For",
				target = targetClone,
				iter = iterClone,
				body = innerBody,
				orelse = {},
				lineno = targetClone.lineno or node.lineno,
				col_offset = targetClone.col_offset or node.col_offset,
			},
		}
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

return function(deps: { compileStmt: (CompilerState, any) -> () })
	local compileStmt = deps.compileStmt

	local BINOP_TO_OPCODE: { [BinOpType]: opcodes.Opcode } = {
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

	local COMPARE_TO_OPCODE: { [CmpOp]: number } = {
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

	local compileExpr: (CompilerState, any) -> ()

	local function compileListCompExpr(st: CompilerState, node: ListComp)
		local compState = State.newState()
		compState.code.name = "<listcomp>"
		compState.code.firstlineno = node.lineno
		compState.code.argcount = 0
		compState.code.kwonlyargcount = 0
		compState.code.varnames = {}

		local resultName = State.newTempName(compState, "__listcomp_result_")
		local stmts = buildListCompStatements(node, resultName)
		for _, stmt in ipairs(stmts) do
			compileStmt(compState, stmt)
		end

		local codeIdx = State.addConst(st, compState.code)
		State.emit(st, "LOAD_CONST", codeIdx, node.lineno)
		State.emit(st, "MAKE_FUNCTION", 0, node.lineno)
		State.emit(st, "CALL_FUNCTION", 0, node.lineno)
	end

	local function compileLambdaExpr(st: CompilerState, node: nodes.Lambda)
		local lambdaState = State.newState()
		lambdaState.code.name = "<lambda>"
		lambdaState.code.firstlineno = node.lineno
		lambdaState.code.argcount = if node.args and node.args.args then #node.args.args else 0
		lambdaState.code.kwonlyargcount = 0
		lambdaState.code.varnames = {}

		if node.args and node.args.args then
			for _, arg in ipairs(node.args.args) do
				lambdaState.code.varnames[#lambdaState.code.varnames + 1] = arg.arg
			end
		end

		compileExpr(lambdaState, node.body)
		local retLine = node.body.lineno or node.lineno
		State.emit(lambdaState, "RETURN_VALUE", nil, retLine)

		local codeIdx = State.addConst(st, lambdaState.code)
		State.emit(st, "LOAD_CONST", codeIdx, node.lineno)

		local defaults = if node.args and node.args.defaults then node.args.defaults else {}
		local flags = 0
		if defaults and #defaults > 0 then
			for _, defaultExpr in ipairs(defaults) do
				compileExpr(st, defaultExpr)
			end
			State.emit(st, "BUILD_TUPLE", #defaults, node.lineno)
			flags += 0x01
		end

		State.emit(st, "MAKE_FUNCTION", flags, node.lineno)
	end

	local function withContext(node: any, ctx: ExprContext, fn: () -> ())
		local prev = node.ctx
		node.ctx = ctx
		fn()
		node.ctx = prev
	end

	local function compileName(st: CompilerState, node: any)
		if node.ctx == "Load" then
			local idx = State.addName(st, node.id)
			State.emit(st, "LOAD_NAME", idx, node.lineno)
		elseif node.ctx == "Store" then
			local idx = State.addName(st, node.id)
			State.emit(st, "STORE_NAME", idx, node.lineno)
		else
			error("Unsupported Name ctx: " .. tostring(node.ctx))
		end
	end

	local function compileAssignmentTarget(st: CompilerState, target: any)
		if target.type == "Name" then
			target.ctx = "Store"
			compileName(st, target)
		elseif target.type == "Tuple" then
			target.ctx = "Store"
			local count = #target.elts
			State.emit(st, "UNPACK_SEQUENCE", count, target.lineno)
			for _, elt in ipairs(target.elts) do
				compileAssignmentTarget(st, elt)
			end
		elseif target.type == "Attribute" then
			compileExpr(st, target.value)
			local idx = State.addName(st, target.attr)
			State.emit(st, "STORE_ATTR", idx, target.lineno)
		elseif target.type == "Subscript" then
			compileExpr(st, target.value)
			compileExpr(st, target.slice)
			State.emit(st, "STORE_SUBSCR", nil, target.lineno)
		else
			error("Unsupported assignment target type: " .. tostring(target.type))
		end
	end

	local function compileLoadTarget(st: CompilerState, target: any)
		if target.type == "Name" then
			withContext(target, "Load", function()
				compileName(st, target)
			end)
		elseif target.type == "Attribute" then
			compileExpr(st, target.value)
			local idx = State.addName(st, target.attr)
			State.emit(st, "LOAD_ATTR", idx, target.lineno)
		elseif target.type == "Subscript" then
			compileExpr(st, target.value)
			compileExpr(st, target.slice)
			State.emit(st, "LOAD_SUBSCR", nil, target.lineno)
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
			State.emit(st, "ROT_TWO", nil, target.lineno)
			local idx = State.addName(st, target.attr)
			State.emit(st, "STORE_ATTR", idx, target.lineno)
		elseif target.type == "Subscript" then
			compileExpr(st, target.value)
			State.emit(st, "ROT_TWO", nil, target.lineno)
			compileExpr(st, target.slice)
			State.emit(st, "ROT_TWO", nil, target.lineno)
			State.emit(st, "STORE_SUBSCR", nil, target.lineno)
		else
			error("Unsupported store target type: " .. tostring(target.type))
		end
	end

	compileExpr = function(st: CompilerState, node: any)
		local t = node.type
		if t == "Constant" then
			if node.kind == "bytes" then
				local tagged = { __bytes_literal = true, value = node.value }
				local idx = State.addConst(st, tagged)
				State.emit(st, "LOAD_CONST", idx, node.lineno)
			else
				local idx = State.addConst(st, node.value)
				State.emit(st, "LOAD_CONST", idx, node.lineno)
			end
		elseif t == "Name" then
			compileName(st, node)
		elseif t == "Attribute" then
			compileExpr(st, node.value)
			local idx = State.addName(st, node.attr)
			State.emit(st, "LOAD_ATTR", idx, node.lineno)
		elseif t == "Subscript" then
			compileExpr(st, node.value)
			compileExpr(st, node.slice)
			State.emit(st, "LOAD_SUBSCR", nil, node.lineno)
		elseif t == "BinOp" then
			compileExpr(st, node.left)
			compileExpr(st, node.right)
			local op = BINOP_TO_OPCODE[node.op]
			if not op then
				error("Unsupported binary op: " .. tostring(node.op))
			end
			State.emit(st, (op :: any) :: opcodes.Opcode, nil, node.lineno)
		elseif t == "UnaryOp" then
			compileExpr(st, node.operand)
			if node.op == "UAdd" then
				State.emit(st, "UNARY_POSITIVE", nil, node.lineno)
			elseif node.op == "USub" then
				State.emit(st, "UNARY_NEGATIVE", nil, node.lineno)
			elseif node.op == "Not" then
				State.emit(st, "UNARY_NOT", nil, node.lineno)
			elseif node.op == "Invert" then
				State.emit(st, "UNARY_INVERT", nil, node.lineno)
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
					State.emit(st, "DUP_TOP", nil, lineno)
					State.emit(st, "ROT_THREE", nil, lineno)
				end

				local opcode = COMPARE_TO_OPCODE[op]
				if opcode == nil then
					error("Unsupported comparison op: " .. tostring(op))
				end
				State.emit(st, "COMPARE_OP", opcode, lineno)

				if not isLast then
					local jumpAddr = State.getCurrentAddress(st)
					State.emit(st, "JUMP_IF_FALSE_OR_POP", 0, lineno)
					falseJumpFixups[#falseJumpFixups + 1] = jumpAddr
				end
			end

			if #falseJumpFixups > 0 then
				local jumpPastCleanup = State.getCurrentAddress(st)
				State.emit(st, "JUMP_FORWARD", 0, node.lineno)

				local cleanupAddr = State.getCurrentAddress(st)
				State.emit(st, "ROT_TWO", nil, node.lineno)
				State.emit(st, "POP_TOP", nil, node.lineno)
				local doneAddr = State.getCurrentAddress(st)

				for _, addr in ipairs(falseJumpFixups) do
					State.patchJump(st, addr, cleanupAddr)
				end
				State.patchJump(st, jumpPastCleanup, doneAddr)
			end
		elseif t == "Call" then
			compileExpr(st, node.func)
			for _, arg in ipairs(node.args) do
				compileExpr(st, arg)
			end
			State.emit(st, "CALL_FUNCTION", #node.args, node.lineno)
		elseif t == "ListComp" then
			compileListCompExpr(st, node)
		elseif t == "Lambda" then
			compileLambdaExpr(st, node)
		elseif t == "List" then
			for _, elt in ipairs(node.elts) do
				compileExpr(st, elt)
			end
			State.emit(st, "BUILD_LIST", #node.elts, node.lineno)
		elseif t == "Tuple" then
			for _, elt in ipairs(node.elts) do
				compileExpr(st, elt)
			end
			State.emit(st, "BUILD_TUPLE", #node.elts, node.lineno)
		elseif t == "Set" then
			for _, elt in ipairs(node.elts) do
				compileExpr(st, elt)
			end
			State.emit(st, "BUILD_SET", #node.elts, node.lineno)
		elseif t == "Dict" then
			local count = #node.keys
			local hasUnpack = false
			for i = 1, count do
				local key = node.keys[i]
				if key and key.type == "DictUnpack" then
					hasUnpack = true
					break
				end
			end

			if not hasUnpack then
				for i = 1, count do
					local key = node.keys[i]
					local value = node.values[i]
					compileExpr(st, key)
					compileExpr(st, value)
				end
				State.emit(st, "BUILD_MAP", count, node.lineno)
			else
				local segments = 0
				local currentPairs: { { key: any, value: any } } = {}

				local function flushCurrentPairs()
					if #currentPairs == 0 then
						return
					end
					for _, pair in ipairs(currentPairs) do
						compileExpr(st, pair.key)
						compileExpr(st, pair.value)
					end
					State.emit(st, "BUILD_MAP", #currentPairs, node.lineno)
					segments += 1
					currentPairs = {}
				end

				for i = 1, count do
					local key = node.keys[i]
					local value = node.values[i]
					if key and key.type == "DictUnpack" then
						flushCurrentPairs()
						compileExpr(st, value)
						segments += 1
					else
						currentPairs[#currentPairs + 1] = { key = key, value = value }
					end
				end

				flushCurrentPairs()

				if segments > 0 then
					State.emit(st, "BUILD_MAP_UNPACK", segments, node.lineno)
				else
					State.emit(st, "BUILD_MAP", 0, node.lineno)
				end
			end
		else
			error("Unsupported expression node type: " .. tostring(t))
		end
	end

	local function resolveBinOpOpcode(op: BinOpType)
		return BINOP_TO_OPCODE[op]
	end

	return {
		compileExpr = compileExpr,
		compileAssignmentTarget = compileAssignmentTarget,
		compileLoadTarget = compileLoadTarget,
		compileStoreTarget = compileStoreTarget,
		resolveBinOpOpcode = resolveBinOpOpcode,
	}
end
