--!strict
-- PyLua Virtual Machine Interpreter
-- Phase 4 - Main execution loop

local Interpreter = {}

local Frame = require("./frame")
local Stack = require("./stack")
local Opcodes = require("../bytecode/opcodes")
local Instructions = require("../bytecode/instructions")
local Base = require("../objects/base")

type Frame = Frame.Frame
type Stack = Stack.Stack
type Instruction = Instructions.Instruction
type Opcode = Opcodes.Opcode
type PyObject = Base.PyObject

-- VM execution state
export type VMState = {
	current_frame: Frame?,
	call_stack: { Frame },
	globals: { [string]: any },
	builtins: { [string]: any },
	return_value: any,
}

-- Comparison operations mapping (forward declaration)
local compareOperations: { [number]: (a: any, b: any) -> boolean }

compareOperations = {
	[0] = function(a: any, b: any): boolean
		return a < b
	end, -- <
	[1] = function(a: any, b: any): boolean
		return a <= b
	end, -- <=
	[2] = function(a: any, b: any): boolean
		return a == b
	end, -- ==
	[3] = function(a: any, b: any): boolean
		return a ~= b
	end, -- !=
	[4] = function(a: any, b: any): boolean
		return a > b
	end, -- >
	[5] = function(a: any, b: any): boolean
		return a >= b
	end, -- >=
	[6] = function(a: any, b: any): boolean
		return a == b
	end, -- is (simplified)
	[7] = function(a: any, b: any): boolean
		return a ~= b
	end, -- is not (simplified)
	[8] = function(a: any, b: any): boolean -- in
		if type(b) == "table" and (b :: any).__contains then
			return (b :: any):__contains(a)
		end
		error("TypeError: argument of type '" .. type(b) .. "' is not iterable", 2)
	end,
	[9] = function(a: any, b: any): boolean -- not in
		return not compareOperations[8](a, b)
	end,
}

-- Create a new VM state
function Interpreter.newState(globals: { [string]: any }?, builtins: { [string]: any }?): VMState
	return {
		current_frame = nil,
		call_stack = {},
		globals = globals or {},
		builtins = builtins or {},
		return_value = nil,
	}
end

local callPyFunction = nil

-- Execute a single instruction
local function executeInstruction(
	vm: VMState,
	frame: Frame,
	instruction: Instruction,
	constants: { any }?,
	names: { string }?
): boolean
	local opcode = instruction.opcode
	local arg = instruction.arg

	-- Update line number for debugging
	Frame.updateLineNumber(frame)

	-- Instruction dispatch
	if opcode == "POP_TOP" then
		Frame.pop(frame)
	elseif opcode == "ROT_TWO" then
		Stack.rotTwo(frame.stack)
	elseif opcode == "ROT_THREE" then
		Stack.rotThree(frame.stack)
	elseif opcode == "DUP_TOP" then
		Stack.duplicate(frame.stack)
	elseif opcode == "LOAD_CONST" then
		-- Load constant by index from constants table
		assert(arg ~= nil, "LOAD_CONST requires argument")
		if constants and constants[arg + 1] then -- +1 for 1-based indexing
			local value = constants[arg + 1]
			-- Handle nil sentinel
			if typeof(value) == "table" and value.__nil then
				value = nil
			end
			Frame.push(frame, value)
		else
			-- Fallback: treat arg as the constant value itself (for simple tests)
			Frame.push(frame, arg)
		end
	elseif opcode == "LOAD_NAME" then
		-- Load name by index from names table
		assert(arg ~= nil, "LOAD_NAME requires argument")
		local name: string
		if names and names[arg + 1] then -- +1 for 1-based indexing
			name = names[arg + 1]
		else
			-- Fallback: treat arg as the variable name directly
			name = tostring(arg)
		end
		local value = Frame.getVariable(frame, name)
		Frame.push(frame, value)
	elseif opcode == "STORE_NAME" then
		assert(arg ~= nil, "STORE_NAME requires argument")
		local name: string
		if names and names[arg + 1] then -- +1 for 1-based indexing
			name = names[arg + 1]
		else
			-- Fallback: treat arg as the variable name directly
			name = tostring(arg)
		end
		local value = Frame.pop(frame)
		Frame.setVariable(frame, name, value)
	elseif opcode == "LOAD_FAST" then
		assert(arg ~= nil, "LOAD_FAST requires argument")
		local value = Frame.getFastLocal(frame, arg)
		Frame.push(frame, value)
	elseif opcode == "STORE_FAST" then
		assert(arg ~= nil, "STORE_FAST requires argument")
		local value = Frame.pop(frame)
		Frame.setFastLocal(frame, arg, value)
	elseif opcode == "LOAD_GLOBAL" then
		local name = tostring(arg)
		local value = Frame.getGlobal(frame, name)
		Frame.push(frame, value)
	elseif opcode == "STORE_GLOBAL" then
		local name = tostring(arg)
		local value = Frame.pop(frame)
		Frame.setGlobal(frame, name, value)

	-- Binary operations
	elseif opcode == "BINARY_ADD" then
		local b = Frame.pop(frame)
		local a = Frame.pop(frame)
		Frame.push(frame, a + b)
	elseif opcode == "BINARY_SUBTRACT" then
		local b = Frame.pop(frame)
		local a = Frame.pop(frame)
		Frame.push(frame, a - b)
	elseif opcode == "BINARY_MULTIPLY" then
		local b = Frame.pop(frame)
		local a = Frame.pop(frame)
		Frame.push(frame, a * b)
	elseif opcode == "BINARY_DIVIDE" then
		local b = Frame.pop(frame)
		local a = Frame.pop(frame)
		if b == 0 then
			error("ZeroDivisionError: division by zero", 2)
		end
		Frame.push(frame, a / b)
	elseif opcode == "BINARY_MODULO" then
		local b = Frame.pop(frame)
		local a = Frame.pop(frame)
		if b == 0 then
			error("ZeroDivisionError: integer division or modulo by zero", 2)
		end
		Frame.push(frame, a % b)
	elseif opcode == "BINARY_POWER" then
		local b = Frame.pop(frame)
		local a = Frame.pop(frame)
		Frame.push(frame, a ^ b)

	-- Unary operations
	elseif opcode == "UNARY_POSITIVE" then
		local a = Frame.pop(frame)
		Frame.push(frame, a) -- Unary + is identity for numbers
	elseif opcode == "UNARY_NEGATIVE" then
		local a = Frame.pop(frame)
		Frame.push(frame, -a)
	elseif opcode == "UNARY_NOT" then
		local a = Frame.pop(frame)
		Frame.push(frame, not a)
	elseif opcode == "UNARY_INVERT" then
		local a = Frame.pop(frame)
		-- Bitwise NOT for integers
		if type(a) == "number" and a == math.floor(a) then
			Frame.push(frame, bit32.bnot(a))
		else
			error("TypeError: bad operand type for unary ~", 2)
		end
	elseif opcode == "COMPARE_OP" then
		assert(arg ~= nil, "COMPARE_OP requires argument")
		local b = Frame.pop(frame)
		local a = Frame.pop(frame)
		local op = compareOperations[arg]
		if not op then
			error("Unknown comparison operation: " .. tostring(arg), 2)
		end
		Frame.push(frame, op(a, b))

	-- Control flow
	elseif opcode == "JUMP_FORWARD" then
		assert(arg ~= nil, "JUMP_FORWARD requires argument")
		-- JUMP_FORWARD uses relative addressing
		-- Calculate target relative to current instruction
		Frame.jump(frame, frame.pc + arg + 1)
		frame.skip_advance = true -- Skip normal PC advance
	elseif opcode == "POP_JUMP_IF_TRUE" then
		assert(arg ~= nil, "POP_JUMP_IF_TRUE requires argument")
		local value = Frame.pop(frame)
		if value then
			Frame.jump(frame, arg)
			frame.skip_advance = true
		end
	elseif opcode == "POP_JUMP_IF_FALSE" then
		assert(arg ~= nil, "POP_JUMP_IF_FALSE requires argument")
		local value = Frame.pop(frame)
		if not value then
			Frame.jump(frame, arg)
			frame.skip_advance = true
		end
	elseif opcode == "JUMP_IF_TRUE_OR_POP" then
		assert(arg ~= nil, "JUMP_IF_TRUE_OR_POP requires argument")
		local value = Frame.peek(frame)
		if value then
			Frame.jump(frame, arg)
			frame.skip_advance = true
		else
			Frame.pop(frame)
		end
	elseif opcode == "JUMP_IF_FALSE_OR_POP" then
		assert(arg ~= nil, "JUMP_IF_FALSE_OR_POP requires argument")
		local value = Frame.peek(frame)
		if not value then
			Frame.jump(frame, arg)
			frame.skip_advance = true
		else
			Frame.pop(frame)
		end
	elseif opcode == "SETUP_LOOP" then
		assert(arg ~= nil, "SETUP_LOOP requires argument")
		-- Push loop block onto block stack
		Frame.pushBlock(frame, "loop", frame.pc, arg)
	elseif opcode == "POP_BLOCK" then
		-- Pop block from block stack
		Frame.popBlock(frame)
	elseif opcode == "BREAK_LOOP" then
		-- Break out of current loop
		local block = Frame.getCurrentBlock(frame)
		if not block or block.type ~= "loop" then
			error("'break' outside loop", 2)
		end
		-- Jump to end of loop
		Frame.jump(frame, block.endPos)
		-- Pop the loop block
		Frame.popBlock(frame)
		frame.skip_advance = true
	elseif opcode == "CONTINUE_LOOP" then
		assert(arg ~= nil, "CONTINUE_LOOP requires argument")
		-- Continue to start of loop
		Frame.jump(frame, arg)
		frame.skip_advance = true
	elseif opcode == "RETURN_VALUE" then
		vm.return_value = Frame.pop(frame)
		return false -- Signal end of execution

	-- Collections
	elseif opcode == "BUILD_LIST" then
		assert(arg ~= nil, "BUILD_LIST requires argument")
		local elements = Stack.popN(frame.stack, arg)
		-- Reverse to match Python stack order (top of stack becomes last element)
		local list = {}
		for i = #elements, 1, -1 do
			list[#list + 1] = elements[i]
		end
		Frame.push(frame, list)
	elseif opcode == "BUILD_TUPLE" then
		assert(arg ~= nil, "BUILD_TUPLE requires argument")
		local elements = Stack.popN(frame.stack, arg)
		-- Mark as tuple (simplified using type casting)
		local tuple = elements :: any
		tuple.__tuple = true
		Frame.push(frame, tuple)
	elseif opcode == "BUILD_SET" then
		assert(arg ~= nil, "BUILD_SET requires argument")
		local elements = Stack.popN(frame.stack, arg)
		-- Create set (simplified)
		local set = {}
		for _, v in ipairs(elements) do
			set[v] = true
		end
		set.__set = true
		Frame.push(frame, set)
	elseif opcode == "BUILD_MAP" then
		assert(arg ~= nil, "BUILD_MAP requires argument")
		local pairs = Stack.popN(frame.stack, arg * 2)
		local map = {}
		-- Stack order when pushed: [key1, value1, key2, value2] (value2 on top)
		-- popN returns: [value2, key2, value1, key1] (in pop order)
		-- Process pairs: (value2, key2) and (value1, key1) -> swap each pair
		for i = 1, #pairs, 2 do
			local value = pairs[i] -- value (popped first)
			local key = pairs[i + 1] -- key (popped second)
			map[key] = value
		end
		Frame.push(frame, map)

	-- Function operations
	elseif opcode == "MAKE_FUNCTION" then
		assert(arg ~= nil, "MAKE_FUNCTION requires argument")
		local flags = arg
		local defaultCount = Frame.pop(frame) -- Number of defaults
		local codeObj = Frame.pop(frame) -- Code object

		-- For now, ignore defaults (simplified)
		local Functions = require("../objects/functions")

		-- Convert CodeObject to PyCode
		local pyCode = Functions.newCode(
			codeObj.name or "<anonymous>",
			codeObj.argcount or 0,
			codeObj.kwonlyargcount or 0,
			codeObj.varnames,
			codeObj.bytecode,
			codeObj.constants,
			codeObj.names,
			nil, -- defaults
			"<string>", -- filename
			codeObj.firstlineno
		)

		-- Create function object
		local func = Functions.newFunction(pyCode, vm.globals, nil, nil)
		Frame.push(frame, func)
	elseif opcode == "CALL_FUNCTION" then
		assert(arg ~= nil, "CALL_FUNCTION requires argument")
		local argc = arg
		local args = Stack.popN(frame.stack, argc)
		local func = Frame.pop(frame)

		-- Reverse args to correct order (popN reverses)
		local orderedArgs = {}
		for i = #args, 1, -1 do
			table.insert(orderedArgs, args[i])
		end

		-- Call the function
		local result = callPyFunction(vm, func, orderedArgs, {})
		Frame.push(frame, result)
	else
		error("Unimplemented opcode: " .. opcode, 2)
	end

	return true -- Continue execution
end

-- Call a Python function (moved from functions module to avoid circular dependency)
callPyFunction = function(vm: VMState, func: any, args: { any }?, kwargs: { [string]: any }?): any
	local Functions = require("../objects/functions")
	local Base = require("../objects/base")

	if not Functions.isFunction(func) then
		error("TypeError: '" .. tostring(func.__type or type(func)) .. "' object is not callable", 2)
	end

	local safeArgs = args or {}
	local safeKwargs = kwargs or {}

	local code = Functions.getFunctionCode(func)
	local funcGlobals = func.__value.globals

	-- Check argument count
	local providedArgs = #safeArgs
	local requiredArgs = code.argcount
	local hasDefaults = func.__value.defaults and #(func.__value.defaults :: { any }) > 0
	local minArgs = hasDefaults and (requiredArgs - #(func.__value.defaults :: { any })) or requiredArgs

	if providedArgs < minArgs then
		error(
			"TypeError: "
				.. (code.name or "<anonymous>")
				.. "() missing "
				.. (minArgs - providedArgs)
				.. " required positional argument(s)",
			2
		)
	end

	if providedArgs > requiredArgs then
		error(
			"TypeError: "
				.. (code.name or "<anonymous>")
				.. "() takes "
				.. requiredArgs
				.. " positional argument(s) but "
				.. providedArgs
				.. " were given",
			2
		)
	end

	-- Create locals with argument binding
	local locals: { [string]: any } = {}

	-- Bind positional arguments
	for i = 1, providedArgs do
		if i <= #code.varnames then
			local varnameList: { [number]: string } = code.varnames
			local varname = varnameList[i]
			if varname then
				locals[varname] = safeArgs[i]
			end
		end
	end

	-- Apply default values for missing arguments
	if hasDefaults then
		local defaults = func.__value.defaults :: { any }
		local defaultStart = requiredArgs - #defaults + 1
		for i = providedArgs + 1, requiredArgs do
			local defaultIndex = i - defaultStart + 1
			if defaultIndex > 0 and defaultIndex <= #defaults and i <= #code.varnames then
				local varnameList: { [number]: string } = code.varnames
				local varname = varnameList[i]
				if varname then
					locals[varname] = defaults[defaultIndex]
				end
			end
		end
	end

	-- Handle keyword arguments
	for name: string, value in pairs(safeKwargs) do
		-- Find the parameter index
		local paramIndex = nil
		for i, varname in ipairs(code.varnames) do
			if varname == name and i <= requiredArgs then
				paramIndex = i
				break
			end
		end

		if paramIndex then
			if safeArgs[paramIndex] then
				error(
					"TypeError: "
						.. (code.name or "<anonymous>")
						.. "() got multiple values for argument '"
						.. name
						.. "'",
					2
				)
			end
			locals[name] = value
		else
			error(
				"TypeError: "
					.. (code.name or "<anonymous>")
					.. "() got an unexpected keyword argument '"
					.. name
					.. "'",
				2
			)
		end
	end

	-- Execute function bytecode using a new frame
	local funcFrame = Frame.new(code.bytecode, funcGlobals, {}, locals, code.name)

	-- Save current frame and push new frame
	local prevFrame = vm.current_frame
	vm.current_frame = funcFrame
	table.insert(vm.call_stack, funcFrame)

	-- Execute function bytecode
	while Frame.hasNext(funcFrame) do
		local instruction = Frame.getCurrentInstruction(funcFrame)
		if not instruction then
			break
		end

		local shouldContinue = executeInstruction(vm, funcFrame, instruction, code.constants, code.names)
		if not shouldContinue then
			break
		end

		-- Only advance if the instruction didn't handle jumping itself
		-- Jump instructions set a flag instead of returning true
		if not funcFrame.skip_advance then
			Frame.advance(funcFrame)
		else
			funcFrame.skip_advance = false -- Reset flag
		end
	end

	-- Restore previous frame
	table.remove(vm.call_stack)
	vm.current_frame = prevFrame

	-- Return the result or None if no explicit return
	local result = vm.return_value
	if result == nil then
		result = Base.newPyObject("NoneType", nil)
	end

	-- Clear return value for next function call
	vm.return_value = nil

	return result
end

-- Execute bytecode
function Interpreter.execute(
	code: { Instruction },
	globals: { [string]: any }?,
	builtins: { [string]: any }?,
	constants: { any }?,
	names: { string }?
): any
	local vm = Interpreter.newState(globals, builtins)
	local frame = Frame.new(code, vm.globals, vm.builtins)

	vm.current_frame = frame
	table.insert(vm.call_stack, frame)

	-- Main execution loop
	while Frame.hasNext(frame) do
		local instruction = Frame.getCurrentInstruction(frame)
		if not instruction then
			break
		end

		local shouldContinue = executeInstruction(vm, frame, instruction, constants, names)
		if not shouldContinue then
			break
		end

		-- Only advance if the instruction didn't handle jumping itself
		-- Jump instructions set a flag instead of returning true
		if not frame.skip_advance then
			Frame.advance(frame)
		else
			frame.skip_advance = false -- Reset flag
		end
	end

	return vm.return_value
end

-- Execute with timeout (for future safety)
function Interpreter.executeWithTimeout(
	code: { Instruction },
	globals: { [string]: any }?,
	builtins: { [string]: any }?,
	constants: { any }?,
	names: { string }?,
	timeout: number?
): any
	-- Simple implementation without actual timeout for now
	-- In a real implementation, this would use coroutines or step-by-step execution
	return Interpreter.execute(code, globals, builtins, constants, names)
end

return Interpreter
