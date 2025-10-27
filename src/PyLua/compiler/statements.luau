local State = require("./state")

type CompilerState = State.CompilerState

type StatementDeps = {
	compileExpr: (CompilerState, any) -> (),
	compileAssignmentTarget: (CompilerState, any) -> (),
	compileLoadTarget: (CompilerState, any) -> (),
	compileStoreTarget: (CompilerState, any) -> (),
	resolveBinOpOpcode: (any) -> string?,
}

return function(deps: StatementDeps)
	local compileExpr = deps.compileExpr
	local compileAssignmentTarget = deps.compileAssignmentTarget
	local compileLoadTarget = deps.compileLoadTarget
	local compileStoreTarget = deps.compileStoreTarget
	local resolveBinOpOpcode = deps.resolveBinOpOpcode

	local compileStmt: (CompilerState, any) -> ()

	local function nodeContainsYield(node: any): boolean
		if type(node) ~= "table" then
			return false
		end
		local nodeType = node.type
		if nodeType == "Yield" or nodeType == "YieldFrom" then
			return true
		end
		if nodeType == "FunctionDef" or nodeType == "ClassDef" then
			return false
		end
		if nodeType == "Lambda" then
			return node.body and nodeContainsYield(node.body)
		end
		for _, value in pairs(node) do
			if type(value) == "table" then
				if value.type then
					if nodeContainsYield(value) then
						return true
					end
				else
					for _, item in ipairs(value) do
						if nodeContainsYield(item) then
							return true
						end
					end
				end
			end
		end
		return false
	end

	local function compileTryNoFinally(st: CompilerState, node: any)
		if not node.handlers or #node.handlers == 0 then
			error("try statement must have at least one handler", 2)
		end

		local setupIndex = State.getCurrentAddress(st)
		State.emit(st, "SETUP_EXCEPT", 0, node.lineno)

		for _, stmt in ipairs(node.body) do
			compileStmt(st, stmt)
		end

		State.emit(st, "POP_BLOCK", nil, node.lineno)

		if node.orelse and #node.orelse > 0 then
			for _, stmt in ipairs(node.orelse) do
				compileStmt(st, stmt)
			end
		end

		local jumpPastHandlers = State.getCurrentAddress(st)
		State.emit(st, "JUMP_FORWARD", 0, node.lineno)

		local handlerStarts = {}
		local handlerFallthroughJumps = {}
		local matchFailJumps = {}

		for index, handler in ipairs(node.handlers) do
			local handlerStart = State.getCurrentAddress(st)
			handlerStarts[index] = handlerStart

			local matchJumpIndex: number? = nil
			if handler.expr then
				State.emit(st, "DUP_TOP", nil, handler.lineno)
				local matchNameIdx = State.addName(st, "_pylua_match_exception")
				State.emit(st, "LOAD_NAME", matchNameIdx, handler.lineno)
				State.emit(st, "ROT_TWO", nil, handler.lineno)
				compileExpr(st, handler.expr)
				State.emit(st, "CALL_FUNCTION", 2, handler.lineno)
				matchJumpIndex = State.getCurrentAddress(st)
				State.emit(st, "POP_JUMP_IF_FALSE", 0, handler.lineno)
			end
			if matchJumpIndex then
				matchFailJumps[#matchFailJumps + 1] = { index = index, jump = matchJumpIndex }
			end

			if handler.name then
				local storeIdx = State.addName(st, handler.name)
				State.emit(st, "STORE_NAME", storeIdx, handler.lineno)
			else
				State.emit(st, "POP_TOP", nil, handler.lineno)
			end

			for _, stmt in ipairs(handler.body) do
				compileStmt(st, stmt)
			end

			local exitJump = State.getCurrentAddress(st)
			State.emit(st, "JUMP_FORWARD", 0, handler.lineno)
			handlerFallthroughJumps[#handlerFallthroughJumps + 1] = exitJump
		end

		local unhandledLabel = State.getCurrentAddress(st)
		if #node.handlers > 0 then
			local raiseIdx = State.addName(st, "_pylua_raise")
			State.emit(st, "LOAD_NAME", raiseIdx, node.lineno)
			State.emit(st, "ROT_TWO", nil, node.lineno)
			State.emit(st, "CALL_FUNCTION", 1, node.lineno)
			State.emit(st, "POP_TOP", nil, node.lineno)
		end

		local endLabel = State.getCurrentAddress(st)

		State.patchJump(st, setupIndex, handlerStarts[1])
		State.patchJump(st, jumpPastHandlers, endLabel)

		for _, record in ipairs(matchFailJumps) do
			local target: number? = nil
			for nextIndex = record.index + 1, #handlerStarts do
				local start = handlerStarts[nextIndex]
				if start ~= nil then
					target = start
					break
				end
			end
			State.patchJump(st, record.jump, target or unhandledLabel)
		end

		for _, jump in ipairs(handlerFallthroughJumps) do
			State.patchJump(st, jump, endLabel)
		end
	end

	local function compileTryWithFinally(st: CompilerState, node: any)
		local lineno = node.lineno
		local setupIndex = State.getCurrentAddress(st)
		State.emit(st, "SETUP_FINALLY", 0, lineno)

		if node.handlers and #node.handlers > 0 then
			local inner = {
				type = "Try",
				body = node.body,
				handlers = node.handlers,
				orelse = node.orelse,
				finalbody = {},
				lineno = node.lineno,
				col_offset = node.col_offset,
			}
			compileTryNoFinally(st, inner)
		else
			for _, stmt in ipairs(node.body) do
				compileStmt(st, stmt)
			end
			if node.orelse and #node.orelse > 0 then
				for _, stmt in ipairs(node.orelse) do
					compileStmt(st, stmt)
				end
			end
		end

		State.emit(st, "POP_BLOCK", nil, lineno)
		State.emit(st, "BEGIN_FINALLY", nil, lineno)

		local finalStart = State.getCurrentAddress(st)
		State.patchJump(st, setupIndex, finalStart)

		for _, stmt in ipairs(node.finalbody) do
			compileStmt(st, stmt)
		end

		State.emit(st, "END_FINALLY", nil, lineno)
	end

	local function compileFunctionDef(st: CompilerState, node: any)
		local funcName = node.name
		local args = node.args
		local body = node.body

		local funcState = State.newState()
		funcState.code.name = funcName
		funcState.code.firstlineno = node.lineno
		local isGenerator = false
		if body then
			for _, stmt in ipairs(body) do
				if nodeContainsYield(stmt) then
					isGenerator = true
					break
				end
			end
		end
		funcState.isGenerator = isGenerator
		funcState.code.isGenerator = isGenerator

		local argcount = 0
		local varnames: { string } = {}

		if args and args.args then
			for _, arg in ipairs(args.args) do
				argcount += 1
				varnames[#varnames + 1] = arg.arg or arg.name or ("arg" .. tostring(argcount))
			end
		end

		funcState.code.argcount = argcount
		funcState.code.varnames = varnames

		for _, stmt in ipairs(body) do
			compileStmt(funcState, stmt)
		end

		local idxNone = State.addConst(funcState, nil)
		State.emit(funcState, "LOAD_CONST", idxNone, node.lineno)
		State.emit(funcState, "RETURN_VALUE", nil, node.lineno)

		local funcCodeIdx = State.addConst(st, funcState.code)
		State.emit(st, "LOAD_CONST", funcCodeIdx, node.lineno)

		local defaultCount = 0
		local flags = 0
		if args and args.defaults and #args.defaults > 0 then
			for _, defaultExpr in ipairs(args.defaults) do
				compileExpr(st, defaultExpr)
				defaultCount += 1
			end
			State.emit(st, "BUILD_TUPLE", defaultCount, node.lineno)
			flags += 0x01
		end

		State.emit(st, "MAKE_FUNCTION", flags, node.lineno)

		local nameIdx = State.addName(st, funcName)
		State.emit(st, "STORE_NAME", nameIdx, node.lineno)
	end

	compileStmt = function(st: CompilerState, node: any)
		if node.type == "Expr" then
			compileExpr(st, node.value)
			State.emit(st, "POP_TOP", nil, node.lineno)
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
			local op = resolveBinOpOpcode(node.op)
			if not op then
				error("Unsupported augmented assignment operator: " .. tostring(node.op))
			end
			State.emit(st, (op :: any), nil, node.lineno)
			compileStoreTarget(st, target)
		elseif node.type == "Return" then
			if node.value then
				compileExpr(st, node.value)
			else
				local idx = State.addConst(st, nil)
				State.emit(st, "LOAD_CONST", idx, node.lineno)
			end
			State.emit(st, "RETURN_VALUE", nil, node.lineno)
		elseif node.type == "If" then
			compileExpr(st, node.test)
			local jumpIfFalse = State.getCurrentAddress(st)
			State.emit(st, "POP_JUMP_IF_FALSE", 0, node.lineno)

			for _, stmt in ipairs(node.body) do
				compileStmt(st, stmt)
			end

			if #node.orelse > 0 then
				local jumpToEnd = State.getCurrentAddress(st)
				State.emit(st, "JUMP_FORWARD", 0, node.lineno)
				State.patchJump(st, jumpIfFalse, State.getCurrentAddress(st))

				for _, stmt in ipairs(node.orelse) do
					compileStmt(st, stmt)
				end

				State.patchJump(st, jumpToEnd, State.getCurrentAddress(st))
			else
				State.patchJump(st, jumpIfFalse, State.getCurrentAddress(st))
			end
		elseif node.type == "While" then
			local setupLoop = State.getCurrentAddress(st)
			State.emit(st, "SETUP_LOOP", 0, node.lineno)

			local loopStart = State.getCurrentAddress(st)
			compileExpr(st, node.test)
			local jumpIfFalse = State.getCurrentAddress(st)
			State.emit(st, "POP_JUMP_IF_FALSE", 0, node.lineno)

			State.enterLoop(st, loopStart, jumpIfFalse)

			for _, stmt in ipairs(node.body) do
				compileStmt(st, stmt)
			end

			local currentAddr = State.getCurrentAddress(st)
			local relativeOffset = loopStart - currentAddr - 1
			State.emit(st, "JUMP_FORWARD", relativeOffset, node.lineno)

			local loopEnd = State.getCurrentAddress(st)
			State.patchJump(st, jumpIfFalse, loopEnd)

			if #node.orelse > 0 then
				for _, stmt in ipairs(node.orelse) do
					compileStmt(st, stmt)
				end
			end

			local blockEnd = State.getCurrentAddress(st)
			State.emit(st, "POP_BLOCK", nil, node.lineno)
			State.patchJump(st, setupLoop, blockEnd)

			State.exitLoop(st)
		elseif node.type == "For" then
			compileExpr(st, node.iter)
			State.emit(st, "GET_ITER", nil, node.lineno)

			local setupLoop = State.getCurrentAddress(st)
			State.emit(st, "SETUP_LOOP", 0, node.lineno)

			local loopStart = State.getCurrentAddress(st)

			local forIterJump = State.getCurrentAddress(st)
			State.emit(st, "FOR_ITER", 0, node.lineno)

			State.enterLoop(st, loopStart, forIterJump)

			compileAssignmentTarget(st, node.target)

			for _, stmt in ipairs(node.body) do
				compileStmt(st, stmt)
			end

			local currentAddr = State.getCurrentAddress(st)
			local relativeOffset = loopStart - currentAddr - 1
			State.emit(st, "JUMP_FORWARD", relativeOffset, node.lineno)

			local loopEnd = State.getCurrentAddress(st)
			State.patchJump(st, forIterJump, loopEnd)

			if #node.orelse > 0 then
				for _, stmt in ipairs(node.orelse) do
					compileStmt(st, stmt)
				end
			end

			local blockEnd = State.getCurrentAddress(st)
			State.emit(st, "POP_BLOCK", nil, node.lineno)
			State.patchJump(st, setupLoop, blockEnd)

			State.exitLoop(st)
		elseif node.type == "Break" then
			local loop = State.getCurrentLoop(st)
			if not loop then
				error("'break' outside loop", 2)
			end
			State.emit(st, "BREAK_LOOP", nil, node.lineno)
		elseif node.type == "Continue" then
			local loop = State.getCurrentLoop(st)
			if not loop then
				error("'continue' not properly in loop", 2)
			end
			State.emit(st, "CONTINUE_LOOP", loop.startLabel, node.lineno)
		elseif node.type == "Pass" then
			return
		elseif node.type == "Try" then
			if node.finalbody and #node.finalbody > 0 then
				compileTryWithFinally(st, node)
			else
				compileTryNoFinally(st, node)
			end
		elseif node.type == "FunctionDef" then
			compileFunctionDef(st, node)
		else
			error("Unsupported statement type: " .. tostring(node.type))
		end
	end

	return {
		compileStmt = compileStmt,
	}
end
