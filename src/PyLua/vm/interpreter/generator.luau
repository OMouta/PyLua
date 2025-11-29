local Base = require("../../objects/base")
local FrameModule = require("../frame")
local State = require("./state")

local Generator = {}

export type PyObject = Base.PyObject
export type VMState = State.VMState

export type ResumeFunction = (
	vm: VMState,
	frame: FrameModule.Frame,
	instruction: any,
	constants: { any }?,
	names: { string }?
) -> boolean

export type GeneratorParams = {
	code: any,
	globals: { [string]: any },
	builtins: { [string]: any },
	locals: { [string]: any },
	executeInstruction: ResumeFunction,
}

export type GeneratorInfo = {
	vm: VMState,
	frame: FrameModule.Frame,
	code: any,
	executeInstruction: ResumeFunction,
	lastYield: PyObject?,
	returnValue: PyObject?,
	finished: boolean,
	running: boolean,
	nextSend: PyObject?,
	resumeValue: PyObject?,
	hasResumeValue: boolean,
	object: PyObject?,
}

local generatorType: Base.PyType? = nil

local function ensureGeneratorType(): Base.PyType
	if generatorType then
		return generatorType
	end
	local typeObj: Base.PyType
	local ok, existing = pcall(Base.getTypeObject, "generator")
	if ok then
		typeObj = existing :: Base.PyType
	else
		typeObj = Base.registerType("generator", {})
	end
	generatorType = typeObj
	typeObj.methods = typeObj.methods or {}
	local methods = typeObj.methods :: { [string]: (PyObject, { PyObject }?) -> PyObject }
	if not methods["__iter__"] then
		methods["__iter__"] = function(self: PyObject): PyObject
			return self
		end
	end
	methods["__next__"] = function(self: PyObject): PyObject
		return Generator.resume(self, nil)
	end
	return typeObj
end

local function raiseStopIteration(value: PyObject?): never
	local payloadValue = value or Base.newNone()
	local exc = Base.newPyObject("StopIteration", { value = payloadValue, message = nil })
	exc.__dict = exc.__dict or {}
	(exc.__dict :: any).value = payloadValue
	error(exc, 0)
end

local function runGenerator(info: GeneratorInfo, sendValue: PyObject?): PyObject
	if info.finished then
		return raiseStopIteration(info.returnValue)
	end
	if info.running then
		error("ValueError: generator already executing", 2)
	end

	local incoming = sendValue
	if incoming == nil then
		incoming = Base.newNone()
	else
		incoming = Base.ensurePyObject(incoming)
	end

	local vm = info.vm
	local frame = info.frame

	info.running = true
	vm.current_frame = frame
	table.insert(vm.call_stack, frame)

	local ok, err = pcall(function()
		info.nextSend = incoming
		if info.hasResumeValue and info.resumeValue then
			FrameModule.push(frame, info.resumeValue)
			info.resumeValue = nil
			info.hasResumeValue = false
		end
		while FrameModule.hasNext(frame) do
			local instruction = FrameModule.getCurrentInstruction(frame)
			if not instruction then
				break
			end
			local shouldContinue = info.executeInstruction(vm, frame, instruction, info.code.constants, info.code.names)
			if not shouldContinue then
				break
			end
			if not frame.skip_advance then
				FrameModule.advance(frame)
			else
				frame.skip_advance = false
			end
		end
	end)

	info.running = false
	table.remove(vm.call_stack)
	vm.current_frame = nil

	if not ok then
		error(err, 0)
	end

	if info.lastYield then
		local result = info.lastYield
		info.lastYield = nil
		return result
	end

	if info.finished then
		return raiseStopIteration(info.returnValue)
	end

	-- Generator exhausted without explicit finish marker
	info.finished = true
	return raiseStopIteration(info.returnValue)
end

function Generator.new(params: GeneratorParams): PyObject
	local generatorVm = State.newState(params.globals, params.builtins)
	local frame =
		FrameModule.new(params.code.bytecode, params.globals, params.builtins, params.locals, params.code.name)
	local frameAny = frame :: any
	frameAny.is_generator = true

	local info: GeneratorInfo = {
		vm = generatorVm,
		frame = frame,
		code = params.code,
		executeInstruction = params.executeInstruction,
		lastYield = nil,
		returnValue = Base.newNone(),
		finished = false,
		running = false,
		nextSend = nil,
		resumeValue = nil,
		hasResumeValue = false,
		object = nil,
	}

	ensureGeneratorType()
	local generatorObj = Base.newPyObject("generator", info)
	info.object = generatorObj
	frameAny.generator_state = info

	return generatorObj
end

function Generator.resume(self: PyObject, sendValue: PyObject?): PyObject
	local info = self.__value :: GeneratorInfo
	local result = runGenerator(info, sendValue)
	return result
end

return Generator
