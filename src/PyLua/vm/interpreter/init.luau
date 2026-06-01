local State = require("@self/state")
local Helpers = require("@self/helpers")
local Dispatcher = require("@self/dispatcher")
local Executor = require("@self/executor")
local CallFunction = require("@self/call_function")
local Base = require("../objects/base")

local FrameModule = require("./frame")

local Interpreter = {}

local executeInstruction = Executor.new(Dispatcher.dispatchInstruction)
local callHelpers = CallFunction.new(executeInstruction)
Dispatcher.setCallHelpers(callHelpers)
Base.setPythonCallHelper(callHelpers.call)

function Interpreter.newState(globals: { [string]: any }?, builtins: { [string]: any }?)
	return State.newState(globals, builtins)
end

export type ExecuteOptions = State.VMOptions

function Interpreter.execute(
	code: { any },
	globals: { [string]: any }?,
	builtins: { [string]: any }?,
	constants: { any }?,
	names: { string }?,
	options: ExecuteOptions?
): any
	local vm = State.newState(globals, builtins, options)
	local frame = FrameModule.new(code, vm.globals, vm.builtins)

	vm.current_frame = frame
	table.insert(vm.call_stack, frame)

	local function run()
		Base.setActiveVM(vm)
		while FrameModule.hasNext(frame) do
			State.step(vm)
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
		if not vm.preserve_globals then
			for key, value in pairs(vm.globals) do
				vm.globals[key] = Helpers.unwrapPrimitive(value)
			end
		end
		return ret
	end

	local ok, result = pcall(run)
	Base.setActiveVM(nil)
	if not ok then
		error(result, 0)
	end
	return result
end

function Interpreter.executeWithTimeout(
	code: { any },
	globals: { [string]: any }?,
	builtins: { [string]: any }?,
	constants: { any }?,
	names: { string }?,
	timeout: number?
): any
	local options: ExecuteOptions? = nil
	if timeout and timeout > 0 then
		options = {
			deadline = os.clock() + timeout,
		}
	end
	return Interpreter.execute(code, globals, builtins, constants, names, options)
end

return Interpreter
