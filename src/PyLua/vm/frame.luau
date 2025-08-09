--!strict
-- PyLua Execution Frames
-- Phase 4 - Function call contexts

local Frame = {}

-- Execution frame for function calls
export type Frame = {
	code: any, -- Bytecode being executed
	locals: { [string]: any }, -- Local variables
	globals: { [string]: any }, -- Global variables
	stack: { any }, -- Local value stack
	pc: number, -- Program counter
	lineno: number, -- Current line number
}

-- TODO: Implement frame management in Phase 4

return Frame
