local FrameModule = require("../frame")
local Stack = require("../stack")
local Base = require("../../objects/base")
local Collections = require("../../objects/collections")
local ObjBuiltins = require("../../objects/builtins")
local Exceptions = require("../../builtins/exceptions")
local interop = require("../../interop/bridge")

local Helpers = require("./helpers")
local Iteration = require("./iteration")
local Blocks = require("./blocks")

local Dispatcher = {}

local compareOperations = Helpers.compareOperations

local callPyFunctionRef: ((vm: any, func: any, args: { any }?, kwargs: { [string]: any }?) -> any)? = nil

-- Helper to check if value is already a PyObject (performance optimization)
local function isPyObject(value: any): boolean
	return type(value) == "table" and (value :: any).__type ~= nil
end

-- Helper to ensure value is a PyObject (optimized check first)
local function toPyObject(value: any): any
	return if isPyObject(value) then value else Base.ensurePyObject(value)
end

local function ensureCallFunction(): (vm: any, func: any, args: { any }?, kwargs: { [string]: any }?) -> any
	if not callPyFunctionRef then
		error("Interpreter dispatch: callPyFunction not configured", 2)
	end
	return callPyFunctionRef
end

function Dispatcher.setCallPyFunction(fn: (vm: any, func: any, args: { any }?, kwargs: { [string]: any }?) -> any)
	callPyFunctionRef = fn
end

function Dispatcher.dispatchInstruction(
	vm: any,
	frame: FrameModule.Frame,
	instruction: any,
	constants: { any }?,
	names: { string }?
): boolean
	local opcode = instruction.opcode
	local arg = instruction.arg

	FrameModule.updateLineNumber(frame)

	if opcode == "POP_TOP" then
		FrameModule.pop(frame)
	elseif opcode == "ROT_TWO" then
		Stack.rotTwo(frame.stack)
	elseif opcode == "ROT_THREE" then
		Stack.rotThree(frame.stack)
	elseif opcode == "DUP_TOP" then
		Stack.duplicate(frame.stack)
	elseif opcode == "LOAD_CONST" then
		assert(arg ~= nil, "LOAD_CONST requires argument")
		local value = nil
		if constants then
			value = constants[arg + 1]
		end
		if constants and value ~= nil then
			local resolved = value
			if typeof(resolved) == "table" and resolved.__nil then
				resolved = nil
			elseif typeof(resolved) == "table" and (resolved :: any).__bytes_literal then
				resolved = ObjBuiltins.Bytes((resolved :: any).value)
			elseif typeof(resolved) == "boolean" then
				resolved = if resolved then ObjBuiltins.True() else ObjBuiltins.False()
			end
			FrameModule.push(frame, resolved)
		else
			FrameModule.push(frame, arg)
		end
	elseif opcode == "LOAD_NAME" then
		assert(arg ~= nil, "LOAD_NAME requires argument")
		local name: string
		if names and names[arg + 1] then
			name = names[arg + 1]
		else
			name = tostring(arg)
		end
		local value = FrameModule.getVariable(frame, name)
		FrameModule.push(frame, value)
	elseif opcode == "STORE_NAME" then
		assert(arg ~= nil, "STORE_NAME requires argument")
		local name: string
		if names and names[arg + 1] then
			name = names[arg + 1]
		else
			name = tostring(arg)
		end
		local value = FrameModule.pop(frame)
		FrameModule.setVariable(frame, name, value)
	elseif opcode == "LOAD_FAST" then
		assert(arg ~= nil, "LOAD_FAST requires argument")
		local value = FrameModule.getFastLocal(frame, arg)
		FrameModule.push(frame, value)
	elseif opcode == "STORE_FAST" then
		assert(arg ~= nil, "STORE_FAST requires argument")
		local value = FrameModule.pop(frame)
		FrameModule.setFastLocal(frame, arg, value)
	elseif opcode == "LOAD_GLOBAL" then
		local name = tostring(arg)
		local value = FrameModule.getGlobal(frame, name)
		FrameModule.push(frame, value)
	elseif opcode == "STORE_GLOBAL" then
		local name = tostring(arg)
		local value = FrameModule.pop(frame)
		FrameModule.setGlobal(frame, name, value)
	elseif opcode == "LOAD_ATTR" then
		assert(arg ~= nil, "LOAD_ATTR requires argument")
		local obj = FrameModule.pop(frame)
		local name: string
		if names and names[arg + 1] then
			name = names[arg + 1]
		else
			name = tostring(arg)
		end
		local pyObj = toPyObject(obj)
		local value = Base.getattr(pyObj, name)
		FrameModule.push(frame, value)
	elseif opcode == "STORE_ATTR" then
		assert(arg ~= nil, "STORE_ATTR requires argument")
		local value = FrameModule.pop(frame)
		local obj = FrameModule.pop(frame)
		local name: string
		if names and names[arg + 1] then
			name = names[arg + 1]
		else
			name = tostring(arg)
		end
		local pyObj = toPyObject(obj)
		local pyValue = toPyObject(value)
		Base.setattr(pyObj, name, pyValue)
	elseif opcode == "LOAD_SUBSCR" then
		local index = FrameModule.pop(frame)
		local container = FrameModule.pop(frame)
		local pyContainer = toPyObject(container)
		local pyIndex = toPyObject(index)
		local getter = Base.getattr(pyContainer, "__getitem__")
		local result = Base.call(getter, { pyIndex })
		FrameModule.push(frame, result)
	elseif opcode == "STORE_SUBSCR" then
		local value = FrameModule.pop(frame)
		local index = FrameModule.pop(frame)
		local container = FrameModule.pop(frame)
		local pyContainer = toPyObject(container)
		local pyIndex = toPyObject(index)
		local pyValue = toPyObject(value)
		local setter = Base.getattr(pyContainer, "__setitem__")
		Base.call(setter, { pyIndex, pyValue })
	elseif opcode == "BINARY_ADD" then
		local b = FrameModule.pop(frame)
		local a = FrameModule.pop(frame)
		local left = toPyObject(a)
		local right = toPyObject(b)
		FrameModule.push(frame, Base.operate("add", left :: any, right :: any))
	elseif opcode == "BINARY_SUBTRACT" then
		local b = FrameModule.pop(frame)
		local a = FrameModule.pop(frame)
		local aVal = (type(a) == "table" and a.__value ~= nil) and a.__value or a
		local bVal = (type(b) == "table" and b.__value ~= nil) and b.__value or b
		FrameModule.push(frame, Base.ensurePyObject(aVal - bVal))
	elseif opcode == "BINARY_MULTIPLY" then
		local b = FrameModule.pop(frame)
		local a = FrameModule.pop(frame)
		local aVal = (type(a) == "table" and a.__value ~= nil) and a.__value or a
		local bVal = (type(b) == "table" and b.__value ~= nil) and b.__value or b
		FrameModule.push(frame, Base.ensurePyObject(aVal * bVal))
	elseif opcode == "BINARY_DIVIDE" then
		local b = FrameModule.pop(frame)
		local a = FrameModule.pop(frame)
		local aVal = (type(a) == "table" and a.__value ~= nil) and a.__value or a
		local bVal = (type(b) == "table" and b.__value ~= nil) and b.__value or b
		if bVal == 0 then
			error("ZeroDivisionError: division by zero", 2)
		end
		FrameModule.push(frame, Base.ensurePyObject(aVal / bVal))
	elseif opcode == "BINARY_MODULO" then
		local b = FrameModule.pop(frame)
		local a = FrameModule.pop(frame)
		local aVal = (type(a) == "table" and a.__value ~= nil) and a.__value or a
		local bVal = (type(b) == "table" and b.__value ~= nil) and b.__value or b
		if bVal == 0 then
			error("ZeroDivisionError: integer division or modulo by zero", 2)
		end
		FrameModule.push(frame, Base.ensurePyObject(aVal % bVal))
	elseif opcode == "BINARY_POWER" then
		local b = FrameModule.pop(frame)
		local a = FrameModule.pop(frame)
		local aVal = (type(a) == "table" and a.__value ~= nil) and a.__value or a
		local bVal = (type(b) == "table" and b.__value ~= nil) and b.__value or b
		FrameModule.push(frame, Base.ensurePyObject(aVal ^ bVal))
	elseif opcode == "BINARY_FLOOR_DIVIDE" then
		local b = FrameModule.pop(frame)
		local a = FrameModule.pop(frame)
		local left = toPyObject(a)
		local right = toPyObject(b)
		FrameModule.push(frame, Base.operate("floordiv", left :: any, right :: any))
	elseif opcode == "BINARY_MATRIX_MULTIPLY" then
		local b = FrameModule.pop(frame)
		local a = FrameModule.pop(frame)
		local left = toPyObject(a)
		local right = toPyObject(b)
		FrameModule.push(frame, Base.operate("matmul", left :: any, right :: any))
	elseif opcode == "UNARY_POSITIVE" then
		local a = FrameModule.pop(frame)
		local aVal = (type(a) == "table" and a.__value ~= nil) and a.__value or a
		FrameModule.push(frame, Base.ensurePyObject(aVal))
	elseif opcode == "UNARY_NEGATIVE" then
		local a = FrameModule.pop(frame)
		local aVal = (type(a) == "table" and a.__value ~= nil) and a.__value or a
		FrameModule.push(frame, Base.ensurePyObject(-aVal))
	elseif opcode == "UNARY_NOT" then
		local a = FrameModule.pop(frame)
		local aVal = (type(a) == "table" and a.__value ~= nil) and a.__value or a
		FrameModule.push(frame, Base.ensurePyObject(not aVal))
	elseif opcode == "UNARY_INVERT" then
		local a = FrameModule.pop(frame)
		local aVal = (type(a) == "table" and a.__value ~= nil) and a.__value or a
		if type(aVal) == "number" and aVal == math.floor(aVal) then
			FrameModule.push(frame, Base.ensurePyObject(bit32.bnot(aVal)))
		else
			error("TypeError: bad operand type for unary ~", 2)
		end
	elseif opcode == "COMPARE_OP" then
		assert(arg ~= nil, "COMPARE_OP requires argument")
		local rawRight = FrameModule.pop(frame)
		local rawLeft = FrameModule.pop(frame)
		local op = compareOperations[arg]
		if not op then
			error("Unknown comparison operation: " .. tostring(arg), 2)
		end
		local result
		if arg == 6 or arg == 7 or arg == 8 or arg == 9 then
			result = op(rawLeft, rawRight)
		else
			local leftVal = (type(rawLeft) == "table" and (rawLeft :: any).__value ~= nil) and (rawLeft :: any).__value or rawLeft
			local rightVal = (type(rawRight) == "table" and (rawRight :: any).__value ~= nil) and (rawRight :: any).__value or rawRight
			result = op(leftVal, rightVal)
		end
		-- Optimize: check if result is already PyObject before wrapping
		FrameModule.push(frame, if isPyObject(result) then result else Base.ensurePyObject(result))
	elseif opcode == "JUMP_FORWARD" then
		assert(arg ~= nil, "JUMP_FORWARD requires argument")
		FrameModule.jump(frame, frame.pc + arg + 1)
		frame.skip_advance = true
	elseif opcode == "POP_JUMP_IF_TRUE" then
		assert(arg ~= nil, "POP_JUMP_IF_TRUE requires argument")
		local value = FrameModule.pop(frame)
		local isTrue = if isPyObject(value) then Base.truthy(value) else (value and true or false)
		if isTrue then
			FrameModule.jump(frame, arg)
			frame.skip_advance = true
		end
	elseif opcode == "POP_JUMP_IF_FALSE" then
		assert(arg ~= nil, "POP_JUMP_IF_FALSE requires argument")
		local value = FrameModule.pop(frame)
		local isTrue = if isPyObject(value) then Base.truthy(value) else (value and true or false)
		if not isTrue then
			FrameModule.jump(frame, arg)
			frame.skip_advance = true
		end
	elseif opcode == "JUMP_IF_TRUE_OR_POP" then
		assert(arg ~= nil, "JUMP_IF_TRUE_OR_POP requires argument")
		local value = FrameModule.peek(frame)
		local isTrue = if isPyObject(value) then Base.truthy(value) else (value and true or false)
		if isTrue then
			FrameModule.jump(frame, arg)
			frame.skip_advance = true
		else
			FrameModule.pop(frame)
		end
	elseif opcode == "JUMP_IF_FALSE_OR_POP" then
		assert(arg ~= nil, "JUMP_IF_FALSE_OR_POP requires argument")
		local value = FrameModule.peek(frame)
		local isTrue = if isPyObject(value) then Base.truthy(value) else (value and true or false)
		if not isTrue then
			FrameModule.jump(frame, arg)
			frame.skip_advance = true
		else
			FrameModule.pop(frame)
		end
	elseif opcode == "SETUP_LOOP" then
		assert(arg ~= nil, "SETUP_LOOP requires argument")
		FrameModule.pushBlock(frame, {
			type = "loop",
			start = frame.pc + 1,
			endPos = arg,
			handler = nil,
			stackSize = FrameModule.stackSize(frame),
		})
	elseif opcode == "SETUP_EXCEPT" then
		assert(arg ~= nil, "SETUP_EXCEPT requires argument")
		FrameModule.pushBlock(frame, {
			type = "except",
			handler = arg,
			start = nil,
			endPos = nil,
			stackSize = FrameModule.stackSize(frame),
		})
	elseif opcode == "SETUP_FINALLY" then
		assert(arg ~= nil, "SETUP_FINALLY requires argument")
		FrameModule.pushBlock(frame, {
			type = "finally",
			handler = arg,
			start = nil,
			endPos = nil,
			stackSize = FrameModule.stackSize(frame),
		})
	elseif opcode == "POP_BLOCK" then
		FrameModule.popBlock(frame)
	elseif opcode == "BREAK_LOOP" then
		local loopTarget: number? = nil
		for i = #frame.block_stack, 1, -1 do
			local blk = frame.block_stack[i]
			if blk.type == "loop" then
				loopTarget = blk.endPos
				break
			end
		end
		if loopTarget == nil then
			error("'break' outside loop", 2)
		end
		Blocks.cleanIteratorOnBreak(frame)
		Blocks.handleBreak(frame, loopTarget)
		return true
	elseif opcode == "CONTINUE_LOOP" then
		local continueTarget: number? = nil
		for i = #frame.block_stack, 1, -1 do
			local blk = frame.block_stack[i]
			if blk.type == "loop" then
				continueTarget = blk.start or arg
				break
			end
		end
		if continueTarget == nil then
			error("'continue' not properly in loop", 2)
		end
		Blocks.handleContinue(frame, continueTarget)
		return true
	elseif opcode == "BEGIN_FINALLY" then
		FrameModule.pushFinally(frame, { reason = "normal" })
	elseif opcode == "END_FINALLY" then
		local record = FrameModule.popFinally(frame)
		if record then
			local reason = record.reason
			if reason == "normal" or reason == nil then
				-- no-op
			elseif reason == "return" then
				local continue = Blocks.handleReturn(vm, frame, record.value)
				if not continue then
					return false
				end
				return true
			elseif reason == "break" then
				assert(record.target ~= nil, "break continuation missing target")
				Blocks.handleBreak(frame, record.target :: number)
				return true
			elseif reason == "continue" then
				assert(record.target ~= nil, "continue continuation missing target")
				Blocks.handleContinue(frame, record.target :: number)
				return true
			elseif reason == "exception" then
				local exc = record.value
				Exceptions.reraise(exc :: Helpers.PyObject)
			end
		end
	elseif opcode == "RETURN_VALUE" then
		local value = FrameModule.pop(frame)
		local continue = Blocks.handleReturn(vm, frame, value)
		if not continue then
			return false
		end
		return true
	elseif opcode == "YIELD_VALUE" then
		local value = FrameModule.pop(frame)
		local generatorFlag = (frame :: any).is_generator
		if not generatorFlag then
			error("RuntimeError: 'yield' outside generator", 2)
		end
		local info = (frame :: any).generator_state
		if not info then
			error("RuntimeError: generator metadata missing", 2)
		end
		info.lastYield = Helpers.coercePyObject(value)
		if not info.nextSend then
			info.nextSend = Base.newNone()
		end
		info.resumeValue = info.nextSend
		info.hasResumeValue = true
		info.nextSend = nil
		FrameModule.advance(frame)
		return false
	elseif opcode == "GET_ITER" then
		local iterable = FrameModule.pop(frame)
		local iterator = Iteration.createIterator(iterable)
		FrameModule.push(frame, iterator)
	elseif opcode == "FOR_ITER" then
		assert(arg ~= nil, "FOR_ITER requires argument")
		local iterator = FrameModule.peek(frame)
		local nextValue = Iteration.getNextValue(iterator)
		if nextValue ~= nil then
			FrameModule.push(frame, nextValue)
		else
			FrameModule.pop(frame)
			FrameModule.jump(frame, arg)
			frame.skip_advance = true
		end
	elseif opcode == "UNPACK_SEQUENCE" then
		assert(arg ~= nil, "UNPACK_SEQUENCE requires argument")
		local sequence = FrameModule.pop(frame)
		local values: { any }
		if type(sequence) == "table" then
			local obj = sequence :: any
			if obj.__type == "list" or obj.__type == "tuple" then
				values = obj.__value
			elseif obj.__type == "set" then
				local arr = {}
				for _, entry in pairs(obj.__value) do
					arr[#arr + 1] = entry.value
				end
				values = arr
			else
				error("ValueError: cannot unpack non-sequence", 2)
			end
		else
			error("ValueError: cannot unpack non-sequence", 2)
		end
		if #values ~= arg then
			error(
				string.format(
					"ValueError: too %s values to unpack (expected %d, got %d)",
					if #values < arg then "few" else "many",
					arg,
					#values
				),
				2
			)
		end
		for i = #values, 1, -1 do
			FrameModule.push(frame, values[i])
		end
	elseif opcode == "BUILD_LIST" then
		assert(arg ~= nil, "BUILD_LIST requires argument")
		local elements = Stack.popN(frame.stack, arg)
		-- Pre-allocate array with known size for better performance
		local arr = table.create(arg)
		-- Iterate backwards from elements (which are in reverse stack order)
		local idx = arg
		for i = #elements, 1, -1 do
			arr[idx] = Base.ensurePyObject(elements[i])
			idx -= 1
		end
		local list = Base.newPyObject("list", arr)
		FrameModule.push(frame, list)
	elseif opcode == "BUILD_TUPLE" then
		assert(arg ~= nil, "BUILD_TUPLE requires argument")
		local elements = Stack.popN(frame.stack, arg)
		-- Pre-allocate array with known size for better performance
		local arr = table.create(arg)
		-- Iterate backwards from elements (which are in reverse stack order)
		local idx = arg
		for i = #elements, 1, -1 do
			arr[idx] = Base.ensurePyObject(elements[i])
			idx -= 1
		end
		local tuple = Base.newPyObject("tuple", arr)
		FrameModule.push(frame, tuple)
	elseif opcode == "BUILD_SET" then
		assert(arg ~= nil, "BUILD_SET requires argument")
		local elements = Stack.popN(frame.stack, arg)
		-- Pre-allocate array with known size for better performance
		local values = table.create(arg)
		-- Iterate backwards from elements (which are in reverse stack order)
		local idx = arg
		for i = #elements, 1, -1 do
			values[idx] = Base.ensurePyObject(elements[i])
			idx -= 1
		end
		local set = Collections.newSet(values)
		FrameModule.push(frame, set)
	elseif opcode == "BUILD_MAP" then
		assert(arg ~= nil, "BUILD_MAP requires argument")
		local popped = Stack.popN(frame.stack, arg * 2)
		local entries = {}
		for i = 1, #popped, 2 do
			local value = Base.ensurePyObject(popped[i])
			local key = Base.ensurePyObject(popped[i + 1])
			entries[#entries + 1] = { key, value }
		end
		local dict = Collections.newDict(entries)
		FrameModule.push(frame, dict)
	elseif opcode == "BUILD_MAP_UNPACK" then
		assert(arg ~= nil, "BUILD_MAP_UNPACK requires argument")
		local dicts = Stack.popN(frame.stack, arg)
		local orderedDicts = {}
		for i = #dicts, 1, -1 do
			orderedDicts[#orderedDicts + 1] = dicts[i]
		end
		local merged = Collections.newDict(nil)
		local dictType = Base.getTypeObject("dict")
		local methods = dictType.methods
		if not methods then
			error("Dict type has no methods", 2)
		end
		local setMethod = methods["set"]
		if not setMethod then
			error("Dict type has no set method", 2)
		end
		for _, dictObj in ipairs(orderedDicts) do
			local pyDict = Base.ensurePyObject(dictObj)
			if pyDict.__type ~= "dict" then
				error(string.format("Argument to ** unpacking must be a mapping, not %s", pyDict.__type), 2)
			end
			local storage = pyDict.__value :: any
			if storage then
				for _, entry in pairs(storage) do
					setMethod(merged, { entry.key, entry.value })
				end
			end
		end
		FrameModule.push(frame, merged)
	elseif opcode == "MAKE_FUNCTION" then
		assert(arg ~= nil, "MAKE_FUNCTION requires argument")
		local flags = arg
		if bit32.band(flags, 0x08) ~= 0 then
			FrameModule.pop(frame)
		end
		if bit32.band(flags, 0x04) ~= 0 then
			FrameModule.pop(frame)
		end
		if bit32.band(flags, 0x02) ~= 0 then
			FrameModule.pop(frame)
		end
		local defaults = nil
		if bit32.band(flags, 0x01) ~= 0 then
			local defaultsTuple = FrameModule.pop(frame)
			if defaultsTuple.__type == "tuple" then
				defaults = {}
				for _, value in ipairs(defaultsTuple.__value) do
					table.insert(defaults, value)
				end
			end
		end
		local codeObj = FrameModule.pop(frame)
		local Functions = require("../../objects/functions")
		local pyCode = Functions.newCode(
			codeObj.name or "<anonymous>",
			codeObj.argcount or 0,
			codeObj.kwonlyargcount or 0,
			codeObj.varnames,
			codeObj.bytecode,
			codeObj.constants,
			codeObj.names,
			defaults,
			"<string>",
			codeObj.firstlineno,
			codeObj.isGenerator
		)
		local func = Functions.newFunction(pyCode, vm.globals, defaults, nil)
		FrameModule.push(frame, func)
	elseif opcode == "CALL_FUNCTION" then
		assert(arg ~= nil, "CALL_FUNCTION requires argument")
		local argc = arg
		local args = Stack.popN(frame.stack, argc)
		local func = FrameModule.pop(frame)
		local orderedArgs = {}
		for i = #args, 1, -1 do
			orderedArgs[#orderedArgs + 1] = Helpers.coercePyObject(args[i])
		end
		if type(func) == "table" and func.__type == "builtin_function_or_method" then
			local result = Base.call(func, orderedArgs)
			FrameModule.push(frame, Helpers.coercePyObject(result))
		elseif type(func) == "table" and func.__type == "luau_function" then
			local callMethod = Base.getattr(func, "__call__")
			local result = Base.call(callMethod, orderedArgs)
			FrameModule.push(frame, Helpers.coercePyObject(result))
		elseif type(func) == "function" then
			local wrapped = interop.wrapLuauFunction(func)
			local callMethod = Base.getattr(wrapped, "__call__")
			local result = Base.call(callMethod, orderedArgs)
			FrameModule.push(frame, Helpers.coercePyObject(result))
		else
			local callFn = ensureCallFunction()
			local result = callFn(vm, func, orderedArgs, {})
			FrameModule.push(frame, result)
		end
	else
		error("Unimplemented opcode: " .. opcode, 2)
	end

	return true
end

return Dispatcher
