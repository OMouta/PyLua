local State = require("@self/state")
local Helpers = require("@self/helpers")
local Dispatcher = require("@self/dispatcher")
local Executor = require("@self/executor")
local CallFunction = require("@self/call_function")

local FrameModule = require("./frame")

local Interpreter = {}

local executeInstruction = Executor.new(Dispatcher.dispatchInstruction)
local callPyFunction = CallFunction.new(executeInstruction)
Dispatcher.setCallPyFunction(callPyFunction)

function Interpreter.newState(globals: { [string]: any }?, builtins: { [string]: any }?)
	return State.newState(globals, builtins)
end

function Interpreter.execute(
	code: { any },
	globals: { [string]: any }?,
	builtins: { [string]: any }?,
	constants: { any }?,
	names: { string }?
): any
	local vm = Interpreter.newState(globals, builtins)
	local frame = FrameModule.new(code, vm.globals, vm.builtins)

	vm.current_frame = frame
	table.insert(vm.call_stack, frame)

	while FrameModule.hasNext(frame) do
		local instruction = FrameModule.getCurrentInstruction(frame)
		if not instruction then
			break
		end

		local shouldContinue = executeInstruction(vm, frame, instruction, constants, names)
		if not shouldContinue then
			break
		end

		if not frame.skip_advance then
			FrameModule.advance(frame)
		else
			frame.skip_advance = false
		end
	end

	local ret = Helpers.unwrapPrimitive(vm.return_value)

	for key, value in pairs(vm.globals) do
		vm.globals[key] = Helpers.unwrapPrimitive(value)
	end

	return ret
end

function Interpreter.executeWithTimeout(
	code: { any },
	globals: { [string]: any }?,
	builtins: { [string]: any }?,
	constants: { any }?,
	names: { string }?,
	timeout: number?
): any
	return Interpreter.execute(code, globals, builtins, constants, names)
end

return Interpreter
