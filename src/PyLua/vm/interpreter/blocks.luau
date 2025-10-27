local FrameModule = require("../frame")
local Stack = require("../stack")

local Blocks = {}

export type Frame = FrameModule.Frame
export type Block = FrameModule.Block

local function truncateToBlock(frame: Frame, block: Block)
	local target = block.stackSize
	local current = FrameModule.stackSize(frame)
	if target == nil or target > current then
		target = current
	end
	FrameModule.truncateStack(frame, target)
end

function Blocks.handleReturn(vm: any, frame: Frame, value: any): boolean
	while true do
		local block = FrameModule.getCurrentBlock(frame)
		if not block then
			vm.return_value = value
			return false
		end
		local popped = FrameModule.popBlock(frame)
		if popped then
			truncateToBlock(frame, popped)
			if popped.type == "finally" then
				assert(popped.handler ~= nil, "finally block missing handler")
				FrameModule.pushFinally(frame, { reason = "return", value = value })
				FrameModule.jump(frame, popped.handler :: number)
				frame.skip_advance = true
				return true
			end
		end
	end
end

function Blocks.handleBreak(frame: Frame, target: number?)
	while true do
		local block = FrameModule.popBlock(frame)
		if not block then
			error("'break' outside loop", 2)
		end
		truncateToBlock(frame, block)
		if block.type == "finally" then
			assert(block.handler ~= nil, "finally block missing handler")
			FrameModule.pushFinally(frame, { reason = "break", target = target })
			FrameModule.jump(frame, block.handler :: number)
			frame.skip_advance = true
			return
		elseif block.type == "loop" then
			local exitTarget = target or block.endPos
			assert(exitTarget ~= nil, "Loop block missing end position")
			FrameModule.jump(frame, exitTarget :: number)
			frame.skip_advance = true
			return
		end
	end
end

function Blocks.handleContinue(frame: Frame, target: number?)
	while true do
		local block = FrameModule.getCurrentBlock(frame)
		if not block then
			error("'continue' not properly in loop", 2)
		end
		if block.type == "finally" then
			local popped = FrameModule.popBlock(frame)
			if popped then
				truncateToBlock(frame, popped)
				assert(popped.handler ~= nil, "finally block missing handler")
				FrameModule.pushFinally(frame, { reason = "continue", target = target })
				FrameModule.jump(frame, popped.handler :: number)
				frame.skip_advance = true
				return
			end
		elseif block.type == "loop" then
			local nextTarget = target or block.start
			if nextTarget == nil then
				error("Loop block missing start label for continue", 2)
			end
			FrameModule.jump(frame, nextTarget :: number)
			frame.skip_advance = true
			return
		else
			local popped = FrameModule.popBlock(frame)
			if popped then
				truncateToBlock(frame, popped)
			end
		end
	end
end

function Blocks.cleanIteratorOnBreak(frame: Frame)
	if Stack.isEmpty(frame.stack) then
		return
	end
	local tos = FrameModule.peek(frame)
	if type(tos) ~= "table" then
		return
	end
	local tt = (tos :: any).__type
	if type(tt) == "string" and string.find(tt, "iterator", 1, true) then
		FrameModule.pop(frame)
	end
end

Blocks.truncateToBlock = truncateToBlock

return Blocks
