--!strict
-- PyLua Bytecode Instructions
-- Phase 4 - Instruction definitions and utilities

local Instructions = {}

local opcodes = require('./opcodes')
type Opcode = opcodes.Opcode

-- Bytecode instruction
export type Instruction = {
    opcode: Opcode,
    arg: number?,
    lineno: number?,
}

-- TODO: Implement instruction utilities in Phase 4

return Instructions
