local FrameModule = require("../frame")
local Exceptions = require("../../builtins/exceptions")
local Base = require("../../objects/base")
local Blocks = require("./blocks")
local State = require("./state")

local Executor = {}

export type Frame = FrameModule.Frame
export type Instruction = any
export type VMState = State.VMState
export type PyObject = Base.PyObject

type DispatchFunction = (
	vm: VMState,
	frame: Frame,
	instruction: Instruction,
	constants: { any }?,
	names: { string }?
) -> boolean

local function handleException(
	vm: VMState,
	frame: Frame,
	err: any
): (boolean, PyObject?)
	local excObj = Exceptions.fromLuauError(err)
	while true do
		local block = FrameModule.popBlock(frame)
		if not block then
			return false, excObj
		end
		assert(block.stackSize ~= nil, "Block is missing required stackSize")
		Blocks.truncateToBlock(frame, block)
		if block.type == "finally" then
			if not block.handler then
				return false, excObj
			end
			FrameModule.pushFinally(frame, { reason = "exception", value = excObj })
			FrameModule.jump(frame, block.handler)
			frame.skip_advance = true
			return true, nil
		elseif block.type == "except" then
			if not block.handler then
				return false, excObj
			end
			FrameModule.push(frame, excObj)
			FrameModule.jump(frame, block.handler)
			frame.skip_advance = true
			return true, nil
		end
	end
end

function Executor.new(dispatchInstruction: DispatchFunction): DispatchFunction
	local function executeInstruction(
		vm: VMState,
		frame: Frame,
		instruction: Instruction,
		constants: { any }?,
		names: { string }?
	): boolean
		local ok, result = pcall(dispatchInstruction, vm, frame, instruction, constants, names)
		if ok then
			return result
		end
		local handled, excObj = handleException(vm, frame, result)
		if handled then
			return true
		end
		local message = Exceptions.toLuauMessage(excObj :: PyObject)
		error(message, 0)
	end

	return executeInstruction
end

return Executor
