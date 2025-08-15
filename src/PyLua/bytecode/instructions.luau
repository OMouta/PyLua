--!strict
-- PyLua Bytecode Instructions
-- Phase 4 - Instruction definitions and utilities

local Instructions = {}

local opcodes = require("./opcodes")
type Opcode = opcodes.Opcode

-- Bytecode instruction
export type Instruction = {
	opcode: Opcode,
	arg: number?, -- Optional numeric argument (index / delta / small int)
	lineno: number?, -- Source line for debug / traceback
}

-- Create an instruction; validate arg presence vs opcode metadata
function Instructions.make(op: Opcode, arg: number?, lineno: number?): Instruction
	local needs = opcodes.requiresArg(op)
	if needs and arg == nil then
		error("Opcode " .. op .. " requires argument", 2)
	elseif (not needs) and arg ~= nil then
		error("Opcode " .. op .. " does not take argument", 2)
	end
	return { opcode = op, arg = arg, lineno = lineno }
end

-- Pretty print a single instruction
function Instructions.render(inst: Instruction): string
	if inst.arg ~= nil then
		return string.format("%s %d", inst.opcode, inst.arg)
	end
	return inst.opcode
end

-- Pretty print a list of instructions
function Instructions.renderAll(code: { Instruction }): { string }
	local out: { string } = {}
	for i, inst in ipairs(code) do
		local ln = inst.lineno and ("[" .. tostring(inst.lineno) .. "] ") or ""
		out[#out + 1] = string.format("%03d %s%s", i - 1, ln, Instructions.render(inst))
	end
	return out
end

-- Clone instruction (useful for patching / optimization passes later)
function Instructions.clone(inst: Instruction): Instruction
	return { opcode = inst.opcode, arg = inst.arg, lineno = inst.lineno }
end

return Instructions
