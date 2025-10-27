local FrameModule = require("../frame")

local State = {}

export type Frame = FrameModule.Frame

export type VMState = {
	current_frame: Frame?,
	call_stack: { Frame },
	globals: { [string]: any },
	builtins: { [string]: any },
	return_value: any,
}

function State.newState(globals: { [string]: any }?, builtins: { [string]: any }?): VMState
	return {
		current_frame = nil,
		call_stack = {},
		globals = globals or {},
		builtins = builtins or {},
		return_value = nil,
	}
end

return State
