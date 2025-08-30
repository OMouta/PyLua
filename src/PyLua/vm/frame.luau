--!strict
-- PyLua Execution Frames
-- Phase 4 - Function call contexts

local Frame = {}

local Stack = require("./stack")
local Instructions = require("../bytecode/instructions")

type Stack = Stack.Stack
type Instruction = Instructions.Instruction

-- Execution frame for function calls
export type Frame = {
	code: { Instruction }, -- Bytecode being executed
	locals: { [string]: any }, -- Local variables (by name)
	fast_locals: { any }, -- Fast locals (by index)
	globals: { [string]: any }, -- Global variables
	builtins: { [string]: any }, -- Builtin namespace
	stack: Stack, -- Local value stack
	pc: number, -- Program counter (instruction index)
	lineno: number, -- Current line number
	function_name: string?, -- Function name for debugging
	previous: Frame?, -- Previous frame (call stack)
	block_stack: { { type: string, start: number, endPos: number } }, -- Block stack for loops
	skip_advance: boolean?, -- Flag to skip PC advance (for jumps)
}

-- Create a new execution frame
function Frame.new(
	code: { Instruction },
	globals: { [string]: any }?,
	builtins: { [string]: any }?,
	locals: { [string]: any }?,
	function_name: string?
): Frame
	return {
		code = code,
		locals = locals or {},
		fast_locals = {},
		globals = globals or {},
		builtins = builtins or {},
		stack = Stack.new(),
		pc = 1, -- Luau uses 1-based indexing
		lineno = 1,
		function_name = function_name,
		previous = nil,
		block_stack = {},
		skip_advance = false,
	}
end

-- Get current instruction
function Frame.getCurrentInstruction(frame: Frame): Instruction?
	if frame.pc <= 0 or frame.pc > #frame.code then
		return nil
	end
	return frame.code[frame.pc]
end

-- Advance program counter
function Frame.advance(frame: Frame, delta: number?)
	frame.pc = frame.pc + (delta or 1)
end

-- Jump to absolute position
function Frame.jump(frame: Frame, target: number)
	frame.pc = target
end

-- Check if frame has more instructions
function Frame.hasNext(frame: Frame): boolean
	return frame.pc > 0 and frame.pc <= #frame.code
end

-- Get variable by name (searches locals -> globals -> builtins)
function Frame.getVariable(frame: Frame, name: string): any
	-- Search order: locals, globals, builtins
	if frame.locals[name] ~= nil then
		local value = frame.locals[name]
		-- Handle nil sentinel
		if typeof(value) == "table" and value.__nil then
			return nil
		end
		return value
	end

	if frame.globals[name] ~= nil then
		local value = frame.globals[name]
		-- Handle nil sentinel
		if typeof(value) == "table" and value.__nil then
			return nil
		end
		return value
	end

	if frame.builtins[name] ~= nil then
		local value = frame.builtins[name]
		-- Handle nil sentinel
		if typeof(value) == "table" and value.__nil then
			return nil
		end
		return value
	end

	error("NameError: name '" .. name .. "' is not defined", 2)
end

-- Set variable by name (in locals for functions, globals for module)
function Frame.setVariable(frame: Frame, name: string, value: any)
	-- For now, always store in globals at module level
	-- TODO: This should check if we're in a function context
	
	-- Handle nil values with sentinel to avoid disappearing from table
	local storedValue = value
	if value == nil then
		storedValue = { __nil = true }
	end
	
	frame.globals[name] = storedValue
end

-- Get fast local by index
function Frame.getFastLocal(frame: Frame, index: number): any
	local value = frame.fast_locals[index]
	if value == nil then
		error("UnboundLocalError: local variable referenced before assignment", 2)
	end
	return value
end

-- Set fast local by index
function Frame.setFastLocal(frame: Frame, index: number, value: any)
	frame.fast_locals[index] = value
end

-- Get global variable
function Frame.getGlobal(frame: Frame, name: string): any
	local value = frame.globals[name]
	if value == nil then
		-- Try builtins as fallback
		value = frame.builtins[name]
		if value == nil then
			error("NameError: name '" .. name .. "' is not defined", 2)
		end
	end
	return value
end

-- Set global variable
function Frame.setGlobal(frame: Frame, name: string, value: any)
	frame.globals[name] = value
end

-- Update line number from current instruction
function Frame.updateLineNumber(frame: Frame)
	local inst = Frame.getCurrentInstruction(frame)
	if inst and inst.lineno then
		frame.lineno = inst.lineno
	end
end

-- Stack operations (convenience wrappers)
function Frame.push(frame: Frame, value: any)
	Stack.push(frame.stack, value)
end

function Frame.pop(frame: Frame): any
	return Stack.pop(frame.stack)
end

function Frame.peek(frame: Frame): any
	return Stack.peek(frame.stack)
end

function Frame.stackSize(frame: Frame): number
	return Stack.size(frame.stack)
end

-- Block stack operations for loops
function Frame.pushBlock(frame: Frame, blockType: string, start: number, endPos: number)
	table.insert(frame.block_stack, { type = blockType, start = start, endPos = endPos })
end

function Frame.popBlock(frame: Frame): { type: string, start: number, endPos: number }?
	return table.remove(frame.block_stack)
end

function Frame.getCurrentBlock(frame: Frame): { type: string, start: number, endPos: number }?
	return frame.block_stack[#frame.block_stack]
end

return Frame
