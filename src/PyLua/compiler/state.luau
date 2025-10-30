local instructions = require("../bytecode/instructions")
local opcodes = require("../bytecode/opcodes")

type Instruction = instructions.Instruction
type Opcode = opcodes.Opcode

export type CodeObject = {
	constants: { any },
	names: { string },
	varnames: { string },
	bytecode: { Instruction },
	firstlineno: number?,
	lnotab: { number }?,
	name: string?,
	argcount: number?,
	kwonlyargcount: number?,
	isGenerator: boolean?,
}

export type LoopContext = {
	startLabel: number,
	endLabel: number,
}

export type CompilerState = {
	code: CodeObject,
	constIndex: { [string]: number },
	nameIndex: { [string]: number },
	loopStack: { LoopContext },
	labelCounter: number,
	tempNameCounter: number,
	isGenerator: boolean,
}

local State = {}

local function serializeConst(value: any): string
	local t = typeof(value)
	if t == "nil" then
		return "N"
	elseif t == "number" then
		return "F" .. tostring(value)
	elseif t == "boolean" then
		return value and "B1" or "B0"
	elseif t == "string" then
		return "S" .. value
	else
		return "O" .. tostring(value)
	end
end

function State.newState(): CompilerState
	return {
		code = {
			constants = {},
			names = {},
			varnames = {},
			bytecode = {},
			firstlineno = nil,
			lnotab = nil,
			name = nil,
			argcount = nil,
			kwonlyargcount = nil,
			isGenerator = false,
		},
		constIndex = {},
		nameIndex = {},
		loopStack = {},
		labelCounter = 0,
		tempNameCounter = 0,
		isGenerator = false,
	}
end

function State.newTempName(st: CompilerState, prefix: string): string
	st.tempNameCounter += 1
	return prefix .. tostring(st.tempNameCounter)
end

function State.addConst(st: CompilerState, value: any): number
	local key = serializeConst(value)
	local idx = st.constIndex[key]
	if idx then
		return idx
	end

	local storedValue = value
	if value == nil then
		storedValue = { __nil = true }
	end

	table.insert(st.code.constants, storedValue)
	local newIdx = #st.code.constants - 1
	st.constIndex[key] = newIdx
	return newIdx
end

function State.addName(st: CompilerState, name: string): number
	local idx = st.nameIndex[name]
	if idx then
		return idx
	end
	table.insert(st.code.names, name)
	local newIdx = #st.code.names - 1
	st.nameIndex[name] = newIdx
	return newIdx
end

function State.emit(st: CompilerState, op: Opcode, arg: number?, lineno: number?)
	local inst = instructions.make(op, arg, lineno)
	st.code.bytecode[#st.code.bytecode + 1] = inst
end

function State.getCurrentAddress(st: CompilerState): number
	return #st.code.bytecode
end

function State.patchJump(st: CompilerState, jumpAddr: number, targetAddr: number?)
	local target = targetAddr or State.getCurrentAddress(st)
	local instruction = st.code.bytecode[jumpAddr + 1]
	if not instruction then
		return
	end

	if instruction.opcode == "JUMP_FORWARD" then
		local targetIndex = target + 1
		instruction.arg = targetIndex - (jumpAddr + 2)
	else
		instruction.arg = target + 1
	end
end

function State.enterLoop(st: CompilerState, startLabel: number, endLabel: number)
	table.insert(st.loopStack, { startLabel = startLabel, endLabel = endLabel })
end

function State.exitLoop(st: CompilerState)
	table.remove(st.loopStack)
end

function State.getCurrentLoop(st: CompilerState): LoopContext?
	return st.loopStack[#st.loopStack]
end

return State
