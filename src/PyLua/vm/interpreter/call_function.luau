local FrameModule = require("../frame")
local Functions = require("../../objects/functions")
local Instructions = require("../../bytecode/instructions")
local Base = require("../../objects/base")
local State = require("./state")

local CallFunction = {}

export type Frame = FrameModule.Frame
export type VMState = State.VMState
type PyCode = Functions.PyCode
type Instruction = Instructions.Instruction

local function bindPositionalArguments(
	code: PyCode,
	locals: { [string]: any },
	safeArgs: { any }
)
	for i = 1, #safeArgs do
		if i <= #code.varnames then
			local varname = code.varnames[i]
			if varname then
				locals[varname] = safeArgs[i]
			end
		end
	end
end

local function applyDefaultValues(
	code: PyCode,
	locals: { [string]: any },
	safeArgs: { any },
	requiredArgs: number,
	defaults: { any }?
)
	if not defaults or #defaults == 0 then
		return
	end
	local defaultsList = defaults :: { any }
	local defaultStart = requiredArgs - #defaultsList + 1
	for i = #safeArgs + 1, requiredArgs do
		local defaultIndex = i - defaultStart + 1
		if defaultIndex > 0 and defaultIndex <= #defaultsList and i <= #code.varnames then
			local varname = code.varnames[i]
			if varname then
				locals[varname] = defaultsList[defaultIndex]
			end
		end
	end
end

local function bindKeywordArguments(
	code: PyCode,
	locals: { [string]: any },
	safeArgs: { any },
	safeKwargs: { [string]: any },
	requiredArgs: number
)
	for name: string, value in pairs(safeKwargs) do
		local paramIndex = nil
		for i, varname in ipairs(code.varnames) do
			if varname == name and i <= requiredArgs then
				paramIndex = i
				break
			end
		end

		if paramIndex then
			if safeArgs[paramIndex] then
				error(
					"TypeError: "
						.. (code.name or "<anonymous>")
						.. "() got multiple values for argument '"
						.. name
						.. "'",
					2
				)
			end
			locals[name] = value
		else
			error(
				"TypeError: "
					.. (code.name or "<anonymous>")
					.. "() got an unexpected keyword argument '"
					.. name
					.. "'",
				2
			)
		end
	end
end

function CallFunction.new(
	executeInstruction: (
		vm: VMState,
		frame: Frame,
		instruction: Instruction,
		constants: { any }?,
		names: { string }?
	) -> boolean
): (vm: VMState, func: any, args: { any }?, kwargs: { [string]: any }?) -> any
	local function callPyFunction(vm: VMState, func: any, args: { any }?, kwargs: { [string]: any }?): any
		if not Functions.isFunction(func) then
			error("TypeError: '" .. tostring(func.__type or type(func)) .. "' object is not callable", 2)
		end

		local safeArgs = args or {}
		local safeKwargs = kwargs or {}

		local code = Functions.getFunctionCode(func)
		local funcGlobals = func.__value.globals

		local providedArgs = #safeArgs
		local requiredArgs = code.argcount
		local defaultsList = func.__value.defaults :: { any }?
		local defaultsCount = defaultsList and #defaultsList or 0
		local minArgs = if defaultsCount > 0 then requiredArgs - defaultsCount else requiredArgs

		if providedArgs < minArgs then
			error(
				"TypeError: "
					.. (code.name or "<anonymous>")
					.. "() missing "
					.. (minArgs - providedArgs)
					.. " required positional argument(s)",
				2
			)
		end

		if providedArgs > requiredArgs then
			error(
				"TypeError: "
					.. (code.name or "<anonymous>")
					.. "() takes "
					.. requiredArgs
					.. " positional argument(s) but "
					.. providedArgs
					.. " were given",
				2
			)
		end

		local locals: { [string]: any } = {}
		bindPositionalArguments(code, locals, safeArgs)
		applyDefaultValues(code, locals, safeArgs, requiredArgs, defaultsList)
		bindKeywordArguments(code, locals, safeArgs, safeKwargs, requiredArgs)

		local funcFrame = FrameModule.new(code.bytecode, funcGlobals, vm.builtins, locals, code.name)

		local prevFrame = vm.current_frame
		vm.current_frame = funcFrame
		table.insert(vm.call_stack, funcFrame)

		while FrameModule.hasNext(funcFrame) do
			local instruction = FrameModule.getCurrentInstruction(funcFrame)
			if not instruction then
				break
			end

			local shouldContinue = executeInstruction(vm, funcFrame, instruction, code.constants, code.names)
			if not shouldContinue then
				break
			end

			if not funcFrame.skip_advance then
				FrameModule.advance(funcFrame)
			else
				funcFrame.skip_advance = false
			end
		end

		table.remove(vm.call_stack)
		vm.current_frame = prevFrame

		local result = vm.return_value
		if result == nil then
			result = Base.newNone()
		end

		vm.return_value = nil

		return result
	end

	return callPyFunction
end

return CallFunction
