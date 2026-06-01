local FrameModule = require("../frame")

local State = {}

export type Frame = FrameModule.Frame

export type VMState = {
	current_frame: Frame?,
	call_stack: { Frame },
	globals: { [string]: any },
	builtins: { [string]: any },
	return_value: any,
	instruction_count: number,
	max_instructions: number?,
	deadline: number?,
	max_call_depth: number?,
}

export type VMOptions = {
	maxInstructions: number?,
	deadline: number?,
	maxCallDepth: number?,
}

function State.newState(globals: { [string]: any }?, builtins: { [string]: any }?, options: VMOptions?): VMState
	return {
		current_frame = nil,
		call_stack = {},
		globals = globals or {},
		builtins = builtins or {},
		return_value = nil,
		instruction_count = 0,
		max_instructions = options and options.maxInstructions or nil,
		deadline = options and options.deadline or nil,
		max_call_depth = options and options.maxCallDepth or nil,
	}
end

function State.step(vm: VMState)
	vm.instruction_count += 1
	if vm.max_instructions and vm.instruction_count > vm.max_instructions then
		error("RuntimeError: execution instruction budget exceeded", 2)
	end
	if vm.deadline and os.clock() > vm.deadline then
		error("RuntimeError: execution timeout exceeded", 2)
	end
end

return State
