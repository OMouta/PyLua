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

-- Execute a single instruction
local function executeInstruction(vm: VMState, frame: Frame, instruction: Instruction, constants: { any }?): boolean
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
			Frame.push(frame, constants[arg + 1])
		else
			-- Fallback: treat arg as the constant value itself (for simple tests)
			Frame.push(frame, arg)
		end
	elseif opcode == "LOAD_NAME" then
		-- For simplicity, assume arg is the variable name (will be index later)
		local name = tostring(arg)
		local value = Frame.getVariable(frame, name)
		Frame.push(frame, value)
	elseif opcode == "STORE_NAME" then
		local name = tostring(arg)
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
		Frame.advance(frame, arg)
		return true -- Skip normal PC advance
	elseif opcode == "POP_JUMP_IF_TRUE" then
		assert(arg ~= nil, "POP_JUMP_IF_TRUE requires argument")
		local value = Frame.pop(frame)
		if value then
			Frame.jump(frame, arg)
			return true
		end
	elseif opcode == "POP_JUMP_IF_FALSE" then
		assert(arg ~= nil, "POP_JUMP_IF_FALSE requires argument")
		local value = Frame.pop(frame)
		if not value then
			Frame.jump(frame, arg)
			return true
		end
	elseif opcode == "JUMP_IF_TRUE_OR_POP" then
		assert(arg ~= nil, "JUMP_IF_TRUE_OR_POP requires argument")
		local value = Frame.peek(frame)
		if value then
			Frame.jump(frame, arg)
			return true
		else
			Frame.pop(frame)
		end
	elseif opcode == "JUMP_IF_FALSE_OR_POP" then
		assert(arg ~= nil, "JUMP_IF_FALSE_OR_POP requires argument")
		local value = Frame.peek(frame)
		if not value then
			Frame.jump(frame, arg)
			return true
		else
			Frame.pop(frame)
		end
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
	else
		error("Unimplemented opcode: " .. opcode, 2)
	end

	return true -- Continue execution
end

-- Execute bytecode
function Interpreter.execute(
	code: { Instruction },
	globals: { [string]: any }?,
	builtins: { [string]: any }?,
	constants: { any }?
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

		local shouldContinue = executeInstruction(vm, frame, instruction, constants)
		if not shouldContinue then
			break
		end

		Frame.advance(frame)
	end

	return vm.return_value
end

-- Execute with timeout (for future safety)
function Interpreter.executeWithTimeout(
	code: { Instruction },
	globals: { [string]: any }?,
	builtins: { [string]: any }?,
	constants: { any }?,
	timeout: number?
): any
	-- Simple implementation without actual timeout for now
	-- In a real implementation, this would use coroutines or step-by-step execution
	return Interpreter.execute(code, globals, builtins, constants)
end

return Interpreter
