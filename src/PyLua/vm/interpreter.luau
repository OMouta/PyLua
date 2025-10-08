local Interpreter = {}

local Frame = require("./frame")
local Stack = require("./stack")
local Opcodes = require("../bytecode/opcodes")
local Instructions = require("../bytecode/instructions")
local Base = require("../objects/base")
local Collections = require("../objects/collections")
local ObjBuiltins = require("../objects/builtins")
local Exceptions = require("../builtins/exceptions")

type Frame = Frame.Frame
type Stack = Stack.Stack
type Instruction = Instructions.Instruction
type Opcode = Opcodes.Opcode
type PyObject = Base.PyObject

-- VM execution state
export type VMState = {
	current_frame: Frame?,
	call_stack: { Frame },
	globals: { [string]: any },
	builtins: { [string]: any },
	return_value: any,
}

-- Comparison operations mapping (forward declaration)
local compareOperations: { [number]: (a: any, b: any) -> boolean }

compareOperations = {
	[0] = function(a: any, b: any): boolean
		return a < b
	end, -- <
	[1] = function(a: any, b: any): boolean
		return a <= b
	end, -- <=
	[2] = function(a: any, b: any): boolean
		return a == b
	end, -- ==
	[3] = function(a: any, b: any): boolean
		return a ~= b
	end, -- !=
	[4] = function(a: any, b: any): boolean
		return a > b
	end, -- >
	[5] = function(a: any, b: any): boolean
		return a >= b
	end, -- >=
	[6] = function(a: any, b: any): boolean
		return a == b
	end, -- is (simplified)
	[7] = function(a: any, b: any): boolean
		return a ~= b
	end, -- is not (simplified)
	[8] = function(a: any, b: any): boolean -- in
		local container = if type(b) == "table" and (b :: any).__type ~= nil then b else Base.ensurePyObject(b)
		local needle = if type(a) == "table" and (a :: any).__type ~= nil then a else Base.ensurePyObject(a)
		local ok, containsMethod = pcall(function()
			return Base.getattr(container, "__contains__")
		end)
		if ok and containsMethod then
			local result = Base.call(containsMethod, { needle })
			return Base.truthy(result)
		end
		error("TypeError: argument of type '" .. tostring(container.__type or type(b)) .. "' is not iterable", 2)
	end,
	[9] = function(a: any, b: any): boolean -- not in
		return not compareOperations[8](a, b)
	end,
}

-- Iterator helper functions
local function createIterator(iterable: any): any
	-- Create an iterator from an iterable object
	if type(iterable) == "table" then
		local obj = iterable :: any
		if obj.__type == "list" then
			-- Python list iterator
			return {
				__type = "list_iterator",
				__value = obj.__value,
				__index = 1,
				__length = #obj.__value,
			}
		elseif obj.__type == "tuple" then
			-- Python tuple iterator
			return {
				__type = "tuple_iterator",
				__value = obj.__value,
				__index = 1,
				__length = #obj.__value,
			}
		elseif obj.__type == "set" then
			-- Python set iterator - iterate over stored entries (hashed keys -> { value = PyObject })
			local arr = {}
			for _, entry in pairs(obj.__value) do
				arr[#arr + 1] = entry.value
			end
			return {
				__type = "set_iterator",
				__value = arr,
				__index = 1,
				__length = #arr,
			}
		elseif obj.__type == "dict" then
			-- Python dict iterator (iterates over keys); underlying storage is hashed -> { key = PyObject, value = PyObject }
			local keys = {}
			for _, entry in pairs(obj.__value) do
				keys[#keys + 1] = entry.key
			end
			return {
				__type = "dict_iterator",
				__value = keys,
				__index = 1,
				__length = #keys,
			}
		elseif obj.__type == "str" then
			-- Python string iterator (character by character)
			local chars = {}
			local str = obj.__value :: string
			for i = 1, #str do
				chars[i] = Base.newPyObject("str", str:sub(i, i))
			end
			return {
				__type = "str_iterator",
				__value = chars,
				__index = 1,
				__length = #chars,
			}
		elseif obj.__type == "range" then
			local data = obj.__value
			return {
				__type = "range_iterator",
				__value = {
					current = data.start,
					stop = data.stop,
					step = data.step,
				},
			}
		end
	end

	error("TypeError: '" .. tostring(type(iterable)) .. "' object is not iterable", 2)
end

local function getNextValue(iterator: any): any?
	-- Get the next value from an iterator, or nil if exhausted
	if type(iterator) == "table" then
		local iter = iterator :: any
		if iter.__type == "range_iterator" then
			local state = iter.__value
			local current = state.current
			local step = state.step
			local stop = state.stop
			if step > 0 then
				if current >= stop then
					return nil
				end
			else
				if current <= stop then
					return nil
				end
			end
			state.current = current + step
			return Base.newInt(current)
		elseif iter.__index and iter.__length and iter.__index <= iter.__length then
			local value = iter.__value[iter.__index]
			iter.__index = iter.__index + 1
			return value
		end
	end

	return nil -- Iterator exhausted
end

-- Helper: unwrap primitive PyObjects (int/float/bool/str/NoneType) to raw Luau values
local function unwrapPrimitive(v: any): any
	if type(v) == "table" and v.__type ~= nil then
		local t = v.__type
		if t == "NoneType" then
			return nil
		end
		local value = v.__value
		if value ~= nil then
			if t == "int" or t == "float" or t == "bool" or t == "str" then
				return value
			end
		end
	end
	return v
end

-- Create a new VM state
function Interpreter.newState(globals: { [string]: any }?, builtins: { [string]: any }?): VMState
	return {
		current_frame = nil,
		call_stack = {},
		globals = globals or {},
		builtins = builtins or {},
		return_value = nil,
	}
end

local callPyFunction = nil

-- Execute a single instruction
local function dispatchInstruction(
	vm: VMState,
	frame: Frame,
	instruction: Instruction,
	constants: { any }?,
	names: { string }?
): boolean
	local opcode = instruction.opcode
	local arg = instruction.arg

	-- Update line number for debugging
	Frame.updateLineNumber(frame)

	-- Instruction dispatch
	if opcode == "POP_TOP" then
		Frame.pop(frame)
	elseif opcode == "ROT_TWO" then
		Stack.rotTwo(frame.stack)
	elseif opcode == "ROT_THREE" then
		Stack.rotThree(frame.stack)
	elseif opcode == "DUP_TOP" then
		Stack.duplicate(frame.stack)
	elseif opcode == "LOAD_CONST" then
		-- Load constant by index from constants table
		assert(arg ~= nil, "LOAD_CONST requires argument")
		local value = nil
		if constants then
			value = constants[arg + 1]
		end
		if constants and value ~= nil then -- +1 for 1-based indexing
			local resolved = value
			-- Handle nil sentinel
			if typeof(resolved) == "table" and resolved.__nil then
				resolved = nil
			elseif typeof(resolved) == "table" and (resolved :: any).__bytes_literal then
				resolved = ObjBuiltins.Bytes((resolved :: any).value)
			elseif typeof(resolved) == "boolean" then
				-- Convert Luau booleans to Python bool objects
				resolved = if resolved then ObjBuiltins.True() else ObjBuiltins.False()
			end
			Frame.push(frame, resolved)
		else
			-- Fallback: treat arg as the constant value itself (for simple tests)
			Frame.push(frame, arg)
		end
	elseif opcode == "LOAD_NAME" then
		-- Load name by index from names table
		assert(arg ~= nil, "LOAD_NAME requires argument")
		local name: string
		if names and names[arg + 1] then -- +1 for 1-based indexing
			name = names[arg + 1]
		else
			-- Fallback: treat arg as the variable name directly
			name = tostring(arg)
		end
		local value = Frame.getVariable(frame, name)
		Frame.push(frame, value)
	elseif opcode == "STORE_NAME" then
		assert(arg ~= nil, "STORE_NAME requires argument")
		local name: string
		if names and names[arg + 1] then -- +1 for 1-based indexing
			name = names[arg + 1]
		else
			-- Fallback: treat arg as the variable name directly
			name = tostring(arg)
		end
		local value = Frame.pop(frame)
		Frame.setVariable(frame, name, value)
	elseif opcode == "LOAD_FAST" then
		assert(arg ~= nil, "LOAD_FAST requires argument")
		local value = Frame.getFastLocal(frame, arg)
		Frame.push(frame, value)
	elseif opcode == "STORE_FAST" then
		assert(arg ~= nil, "STORE_FAST requires argument")
		local value = Frame.pop(frame)
		Frame.setFastLocal(frame, arg, value)
	elseif opcode == "LOAD_GLOBAL" then
		local name = tostring(arg)
		local value = Frame.getGlobal(frame, name)
		Frame.push(frame, value)
	elseif opcode == "STORE_GLOBAL" then
		local name = tostring(arg)
		local value = Frame.pop(frame)
		Frame.setGlobal(frame, name, value)
	elseif opcode == "LOAD_ATTR" then
		assert(arg ~= nil, "LOAD_ATTR requires argument")
		local obj = Frame.pop(frame)
		local name: string
		if names and names[arg + 1] then
			name = names[arg + 1]
		else
			name = tostring(arg)
		end
		local pyObj = if type(obj) == "table" and (obj :: any).__type ~= nil then obj else Base.ensurePyObject(obj)
		local value = Base.getattr(pyObj, name)
		Frame.push(frame, value)
	elseif opcode == "STORE_ATTR" then
		assert(arg ~= nil, "STORE_ATTR requires argument")
		local value = Frame.pop(frame)
		local obj = Frame.pop(frame)
		local name: string
		if names and names[arg + 1] then
			name = names[arg + 1]
		else
			name = tostring(arg)
		end
		local pyObj = if type(obj) == "table" and (obj :: any).__type ~= nil then obj else Base.ensurePyObject(obj)
		local pyValue = if type(value) == "table" and (value :: any).__type ~= nil
			then value
			else Base.ensurePyObject(value)
		Base.setattr(pyObj, name, pyValue)
	elseif opcode == "LOAD_SUBSCR" then
		local index = Frame.pop(frame)
		local container = Frame.pop(frame)
		local pyContainer = if type(container) == "table" and (container :: any).__type ~= nil
			then container
			else Base.ensurePyObject(container)
		local pyIndex = if type(index) == "table" and (index :: any).__type ~= nil
			then index
			else Base.ensurePyObject(index)
		local getter = Base.getattr(pyContainer, "__getitem__")
		local result = Base.call(getter, { pyIndex })
		Frame.push(frame, result)
	elseif opcode == "STORE_SUBSCR" then
		local value = Frame.pop(frame)
		local index = Frame.pop(frame)
		local container = Frame.pop(frame)
		local pyContainer = if type(container) == "table" and (container :: any).__type ~= nil
			then container
			else Base.ensurePyObject(container)
		local pyIndex = if type(index) == "table" and (index :: any).__type ~= nil
			then index
			else Base.ensurePyObject(index)
		local pyValue = if type(value) == "table" and (value :: any).__type ~= nil
			then value
			else Base.ensurePyObject(value)
		local setter = Base.getattr(pyContainer, "__setitem__")
		Base.call(setter, { pyIndex, pyValue })

	-- Binary operations
	elseif opcode == "BINARY_ADD" then
		local b = Frame.pop(frame)
		local a = Frame.pop(frame)
		local left = if type(a) == "table" and (a :: any).__type ~= nil then a else Base.ensurePyObject(a)
		local right = if type(b) == "table" and (b :: any).__type ~= nil then b else Base.ensurePyObject(b)
		Frame.push(frame, Base.operate("add", left :: any, right :: any))
	elseif opcode == "BINARY_SUBTRACT" then
		local b = Frame.pop(frame)
		local a = Frame.pop(frame)
		local aVal = (type(a) == "table" and a.__value ~= nil) and a.__value or a
		local bVal = (type(b) == "table" and b.__value ~= nil) and b.__value or b
		Frame.push(frame, Base.ensurePyObject(aVal - bVal))
	elseif opcode == "BINARY_MULTIPLY" then
		local b = Frame.pop(frame)
		local a = Frame.pop(frame)
		local aVal = (type(a) == "table" and a.__value ~= nil) and a.__value or a
		local bVal = (type(b) == "table" and b.__value ~= nil) and b.__value or b
		Frame.push(frame, Base.ensurePyObject(aVal * bVal))
	elseif opcode == "BINARY_DIVIDE" then
		local b = Frame.pop(frame)
		local a = Frame.pop(frame)
		local aVal = (type(a) == "table" and a.__value ~= nil) and a.__value or a
		local bVal = (type(b) == "table" and b.__value ~= nil) and b.__value or b
		if bVal == 0 then
			error("ZeroDivisionError: division by zero", 2)
		end
		Frame.push(frame, Base.ensurePyObject(aVal / bVal))
	elseif opcode == "BINARY_MODULO" then
		local b = Frame.pop(frame)
		local a = Frame.pop(frame)
		local aVal = (type(a) == "table" and a.__value ~= nil) and a.__value or a
		local bVal = (type(b) == "table" and b.__value ~= nil) and b.__value or b
		if bVal == 0 then
			error("ZeroDivisionError: integer division or modulo by zero", 2)
		end
		Frame.push(frame, Base.ensurePyObject(aVal % bVal))
	elseif opcode == "BINARY_POWER" then
		local b = Frame.pop(frame)
		local a = Frame.pop(frame)
		local aVal = (type(a) == "table" and a.__value ~= nil) and a.__value or a
		local bVal = (type(b) == "table" and b.__value ~= nil) and b.__value or b
		Frame.push(frame, Base.ensurePyObject(aVal ^ bVal))
	elseif opcode == "BINARY_FLOOR_DIVIDE" then
		local b = Frame.pop(frame)
		local a = Frame.pop(frame)
		local left = if type(a) == "table" and (a :: any).__type ~= nil then a else Base.ensurePyObject(a)
		local right = if type(b) == "table" and (b :: any).__type ~= nil then b else Base.ensurePyObject(b)
		Frame.push(frame, Base.operate("floordiv", left :: any, right :: any))
	elseif opcode == "BINARY_MATRIX_MULTIPLY" then
		local b = Frame.pop(frame)
		local a = Frame.pop(frame)
		local left = if type(a) == "table" and (a :: any).__type ~= nil then a else Base.ensurePyObject(a)
		local right = if type(b) == "table" and (b :: any).__type ~= nil then b else Base.ensurePyObject(b)
		Frame.push(frame, Base.operate("matmul", left :: any, right :: any))

	-- Unary operations
	elseif opcode == "UNARY_POSITIVE" then
		local a = Frame.pop(frame)
		local aVal = (type(a) == "table" and a.__value ~= nil) and a.__value or a
		Frame.push(frame, Base.ensurePyObject(aVal)) -- Unary + is identity for numbers
	elseif opcode == "UNARY_NEGATIVE" then
		local a = Frame.pop(frame)
		local aVal = (type(a) == "table" and a.__value ~= nil) and a.__value or a
		Frame.push(frame, Base.ensurePyObject(-aVal))
	elseif opcode == "UNARY_NOT" then
		local a = Frame.pop(frame)
		local aVal = (type(a) == "table" and a.__value ~= nil) and a.__value or a
		Frame.push(frame, Base.ensurePyObject(not aVal))
	elseif opcode == "UNARY_INVERT" then
		local a = Frame.pop(frame)
		local aVal = (type(a) == "table" and a.__value ~= nil) and a.__value or a
		-- Bitwise NOT for integers
		if type(aVal) == "number" and aVal == math.floor(aVal) then
			Frame.push(frame, Base.ensurePyObject(bit32.bnot(aVal)))
		else
			error("TypeError: bad operand type for unary ~", 2)
		end
	elseif opcode == "COMPARE_OP" then
		assert(arg ~= nil, "COMPARE_OP requires argument")
		local rawRight = Frame.pop(frame)
		local rawLeft = Frame.pop(frame)
		local op = compareOperations[arg]
		if not op then
			error("Unknown comparison operation: " .. tostring(arg), 2)
		end

		local result
		if arg == 8 or arg == 9 then
			local leftObj = if type(rawLeft) == "table" and (rawLeft :: any).__type ~= nil
				then rawLeft
				else Base.ensurePyObject(rawLeft)
			local rightObj = if type(rawRight) == "table" and (rawRight :: any).__type ~= nil
				then rawRight
				else Base.ensurePyObject(rawRight)
			result = op(leftObj, rightObj)
		elseif arg == 6 or arg == 7 then
			-- Identity comparisons should operate on original operands
			result = op(rawLeft, rawRight)
		else
			local leftVal = (type(rawLeft) == "table" and (rawLeft :: any).__value ~= nil) and (rawLeft :: any).__value
				or rawLeft
			local rightVal = (type(rawRight) == "table" and (rawRight :: any).__value ~= nil)
					and (rawRight :: any).__value
				or rawRight
			result = op(leftVal, rightVal)
		end

		if type(result) == "table" and (result :: any).__type ~= nil then
			Frame.push(frame, result)
		else
			Frame.push(frame, Base.ensurePyObject(result))
		end

	-- Control flow
	elseif opcode == "JUMP_FORWARD" then
		assert(arg ~= nil, "JUMP_FORWARD requires argument")
		-- JUMP_FORWARD uses relative addressing
		-- Calculate target relative to current instruction
		Frame.jump(frame, frame.pc + arg + 1)
		frame.skip_advance = true -- Skip normal PC advance
	elseif opcode == "POP_JUMP_IF_TRUE" then
		assert(arg ~= nil, "POP_JUMP_IF_TRUE requires argument")
		local value = Frame.pop(frame)
		local isTrue = if type(value) == "table" and value.__type ~= nil
			then Base.truthy(value)
			else (value and true or false)
		if isTrue then
			Frame.jump(frame, arg)
			frame.skip_advance = true
		end
	elseif opcode == "POP_JUMP_IF_FALSE" then
		assert(arg ~= nil, "POP_JUMP_IF_FALSE requires argument")
		local value = Frame.pop(frame)
		local isTrue = if type(value) == "table" and value.__type ~= nil
			then Base.truthy(value)
			else (value and true or false)
		if not isTrue then
			Frame.jump(frame, arg)
			frame.skip_advance = true
		end
	elseif opcode == "JUMP_IF_TRUE_OR_POP" then
		assert(arg ~= nil, "JUMP_IF_TRUE_OR_POP requires argument")
		local value = Frame.peek(frame)
		local isTrue = if type(value) == "table" and value.__type ~= nil
			then Base.truthy(value)
			else (value and true or false)
		if isTrue then
			Frame.jump(frame, arg)
			frame.skip_advance = true
		else
			Frame.pop(frame)
		end
	elseif opcode == "JUMP_IF_FALSE_OR_POP" then
		assert(arg ~= nil, "JUMP_IF_FALSE_OR_POP requires argument")
		local value = Frame.peek(frame)
		local isTrue = if type(value) == "table" and value.__type ~= nil
			then Base.truthy(value)
			else (value and true or false)
		if not isTrue then
			Frame.jump(frame, arg)
			frame.skip_advance = true
		else
			Frame.pop(frame)
		end
	elseif opcode == "SETUP_LOOP" then
		assert(arg ~= nil, "SETUP_LOOP requires argument")
		-- Push loop block onto block stack; start at next instruction so continue jumps re-evaluate condition
		Frame.pushBlock(frame, {
			type = "loop",
			start = frame.pc + 1,
			endPos = arg,
			handler = nil,
			stackSize = Frame.stackSize(frame),
		})
	elseif opcode == "SETUP_EXCEPT" then
		assert(arg ~= nil, "SETUP_EXCEPT requires argument")
		Frame.pushBlock(frame, {
			type = "except",
			handler = arg,
			start = nil,
			endPos = nil,
			stackSize = Frame.stackSize(frame),
		})
	elseif opcode == "POP_BLOCK" then
		-- Pop block from block stack
		Frame.popBlock(frame)
	elseif opcode == "BREAK_LOOP" then
		-- Break out of current loop
		local block = Frame.getCurrentBlock(frame)
		if not block or block.type ~= "loop" then
			error("'break' outside loop", 2)
		end
		-- If we're inside a for-loop, the iterator is typically on the TOS.
		-- Clean it up so we don't leak it when breaking out early.
		-- Only inspect TOS if stack isn't empty
		if not Stack.isEmpty(frame.stack) then
			local tos = Frame.peek(frame)
			if type(tos) == "table" then
				local tt = (tos :: any).__type
				if type(tt) == "string" and string.find(tt, "iterator", 1, true) then
					Frame.pop(frame)
				end
			end
		end
		-- Jump to end of loop; POP_BLOCK at target will remove the loop block
		assert(block.endPos ~= nil, "Loop block missing end position")
		Frame.jump(frame, block.endPos :: number)
		frame.skip_advance = true
	elseif opcode == "CONTINUE_LOOP" then
		local block = Frame.getCurrentBlock(frame)
		if not block or block.type ~= "loop" then
			error("'continue' not properly in loop", 2)
		end
		local target = block.start
		if target == nil then
			assert(arg ~= nil, "CONTINUE_LOOP requires argument")
			target = arg
		end
		Frame.jump(frame, target :: number)
		frame.skip_advance = true
	elseif opcode == "RETURN_VALUE" then
		vm.return_value = Frame.pop(frame)
		return false -- Signal end of execution

	-- Iteration
	elseif opcode == "GET_ITER" then
		local iterable = Frame.pop(frame)
		local iterator = createIterator(iterable)
		Frame.push(frame, iterator)
	elseif opcode == "FOR_ITER" then
		assert(arg ~= nil, "FOR_ITER requires argument")
		local iterator = Frame.peek(frame) -- Keep iterator on stack
		local nextValue = getNextValue(iterator)
		if nextValue ~= nil then
			-- Got a value; push as-is (PyObject values remain PyObjects)
			Frame.push(frame, nextValue)
		else
			-- Iterator exhausted, pop it and jump to end
			Frame.pop(frame) -- Remove iterator
			Frame.jump(frame, arg)
			frame.skip_advance = true
		end

	-- Unpacking
	elseif opcode == "UNPACK_SEQUENCE" then
		assert(arg ~= nil, "UNPACK_SEQUENCE requires argument")
		local sequence = Frame.pop(frame)
		
		-- Get the underlying array from PyObject sequences
		local values: { any }
		if type(sequence) == "table" then
			local obj = sequence :: any
			if obj.__type == "list" or obj.__type == "tuple" then
				values = obj.__value
			elseif obj.__type == "set" then
				-- Sets are unordered, but we need to extract values
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
		
		-- Check that we have the right number of values
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
		
		-- Push values onto stack in reverse order (rightmost first)
		-- So they can be popped in forward order for assignment
		for i = #values, 1, -1 do
			Frame.push(frame, values[i])
		end

	-- Collections
	elseif opcode == "BUILD_LIST" then
		assert(arg ~= nil, "BUILD_LIST requires argument")
		local elements = Stack.popN(frame.stack, arg)
		-- Reverse to match Python stack order (top of stack becomes last element)
		local arr = {}
		for i = #elements, 1, -1 do
			arr[#arr + 1] = Base.ensurePyObject(elements[i])
		end
		local list = Base.newPyObject("list", arr)
		Frame.push(frame, list)
	elseif opcode == "BUILD_TUPLE" then
		assert(arg ~= nil, "BUILD_TUPLE requires argument")
		local elements = Stack.popN(frame.stack, arg)
		-- Reverse to match Python stack order (top of stack becomes last element)
		local arr = {}
		for i = #elements, 1, -1 do
			arr[#arr + 1] = Base.ensurePyObject(elements[i])
		end
		local tuple = Base.newPyObject("tuple", arr)
		Frame.push(frame, tuple)
	elseif opcode == "BUILD_SET" then
		assert(arg ~= nil, "BUILD_SET requires argument")
		local elements = Stack.popN(frame.stack, arg)
		-- Build using Collections to ensure hashed representation
		local values = {}
		for i = #elements, 1, -1 do
			values[#values + 1] = Base.ensurePyObject(elements[i])
		end
		local set = Collections.newSet(values)
		Frame.push(frame, set)
	elseif opcode == "BUILD_MAP" then
		assert(arg ~= nil, "BUILD_MAP requires argument")
		local popped = Stack.popN(frame.stack, arg * 2)
		-- Build entries as { {key, value}, ... } using proper order
		-- Stack push order: key1, value1, key2, value2 (value2 on top)
		-- popN returns in reverse pop order: value2, key2, value1, key1
		local entries = {}
		for i = 1, #popped, 2 do
			local value = Base.ensurePyObject(popped[i])
			local key = Base.ensurePyObject(popped[i + 1])
			entries[#entries + 1] = { key, value }
		end
		local dict = Collections.newDict(entries)
		Frame.push(frame, dict)
	elseif opcode == "BUILD_MAP_UNPACK" then
		assert(arg ~= nil, "BUILD_MAP_UNPACK requires argument")
		-- Pop N dicts/mappings from the stack and merge them into one
		local dicts = Stack.popN(frame.stack, arg)
		
		-- Reverse to get correct order (first pushed = first in result)
		local orderedDicts = {}
		for i = #dicts, 1, -1 do
			orderedDicts[#orderedDicts + 1] = dicts[i]
		end
		
		-- Start with an empty dict and merge each one
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
			
			-- Verify it's a dict
			if pyDict.__type ~= "dict" then
				error(string.format("Argument to ** unpacking must be a mapping, not %s", pyDict.__type), 2)
			end
			
			-- Merge: copy all key-value pairs from pyDict into merged
			-- In Python, later values overwrite earlier ones
			local storage = pyDict.__value :: any
			if storage then
				for _, entry in pairs(storage) do
					-- Use the set method to add/update the key-value pair
					setMethod(merged, { entry.key, entry.value })
				end
			end
		end
		
		Frame.push(frame, merged)

	-- Function operations
	elseif opcode == "MAKE_FUNCTION" then
		assert(arg ~= nil, "MAKE_FUNCTION requires argument")
		local flags = arg
		
		-- Stack layout (bottom to top):
		-- - code object (pushed first, at bottom)
		-- - defaults tuple (if flag 0x01, pushed after code)
		-- - kwdefaults dict (if flag 0x02) - not implemented yet
		-- - annotations dict (if flag 0x04) - not implemented yet
		-- - closure tuple (if flag 0x08) - not implemented yet
		--
		-- We pop from top to bottom, so reverse order
		
		-- Pop in reverse order: top items first
		-- Pop closure if present
		if bit32.band(flags, 0x08) ~= 0 then
			Frame.pop(frame) -- closure (not implemented)
		end
		-- Pop annotations if present
		if bit32.band(flags, 0x04) ~= 0 then
			Frame.pop(frame) -- annotations (not implemented)
		end
		-- Pop kwdefaults if present
		if bit32.band(flags, 0x02) ~= 0 then
			Frame.pop(frame) -- kwdefaults (not implemented)
		end
		
		-- Pop defaults tuple if present
		local defaults = nil
		if bit32.band(flags, 0x01) ~= 0 then
			local defaultsTuple = Frame.pop(frame)
			-- Convert tuple to array
			if defaultsTuple.__type == "tuple" then
				defaults = {}
				for _, value in ipairs(defaultsTuple.__value) do
					table.insert(defaults, value)
				end
			end
		end
		
		-- Pop code object (at bottom of our items)
		local codeObj = Frame.pop(frame)

		local Functions = require("../objects/functions")

		-- Convert CodeObject to PyCode
		local pyCode = Functions.newCode(
			codeObj.name or "<anonymous>",
			codeObj.argcount or 0,
			codeObj.kwonlyargcount or 0,
			codeObj.varnames,
			codeObj.bytecode,
			codeObj.constants,
			codeObj.names,
			defaults, -- Pass the defaults
			"<string>", -- filename
			codeObj.firstlineno
		)

		-- Create function object
		local func = Functions.newFunction(pyCode, vm.globals, defaults, nil)
		Frame.push(frame, func)
	elseif opcode == "CALL_FUNCTION" then
		assert(arg ~= nil, "CALL_FUNCTION requires argument")
		local argc = arg
		local args = Stack.popN(frame.stack, argc)
		local func = Frame.pop(frame)

		-- Reverse args to correct order (popN reverses)
		local orderedArgs = {}
		for i = #args, 1, -1 do
			orderedArgs[#orderedArgs + 1] = Base.ensurePyObject(args[i])
		end

		-- Call the function
		if type(func) == "table" and func.__type == "builtin_function_or_method" then
			local result = Base.call(func, orderedArgs)
			Frame.push(frame, Base.ensurePyObject(result))
		else
			local result = callPyFunction(vm, func, orderedArgs, {})
			Frame.push(frame, result)
		end
	else
		error("Unimplemented opcode: " .. opcode, 2)
	end

	return true -- Continue execution
end

local function handleException(vm: VMState, frame: Frame, err: any): (boolean, PyObject?)
	local excObj = Exceptions.fromLuauError(err)
	while true do
		local block = Frame.popBlock(frame)
		if not block then
			return false, excObj
		end
		assert(block.stackSize ~= nil, "Block is missing required stackSize")
		Frame.truncateStack(frame, block.stackSize)
		if block.type == "except" then
			if not block.handler then
				return false, excObj
			end
			Frame.push(frame, excObj)
			Frame.jump(frame, block.handler)
			frame.skip_advance = true
			return true, nil
		end
	end
end

local function executeInstruction(
	vm: VMState,
	frame: Frame,
	instruction: Instruction,
	constants: { any }?,
	names: { string }?
): boolean
	local ok, result = pcall(dispatchInstruction, vm, frame, instruction, constants, names)
	if ok then
		return result
	end
	local handled, excObj = handleException(vm, frame, result)
	if handled then
		return true
	end
	local message = Exceptions.toLuauMessage(excObj :: PyObject)
	error(message, 0)
end

-- Call a Python function (moved from functions module to avoid circular dependency)
callPyFunction = function(vm: VMState, func: any, args: { any }?, kwargs: { [string]: any }?): any
	local Functions = require("../objects/functions")
	local Base = require("../objects/base")

	if not Functions.isFunction(func) then
		error("TypeError: '" .. tostring(func.__type or type(func)) .. "' object is not callable", 2)
	end

	local safeArgs = args or {}
	local safeKwargs = kwargs or {}

	local code = Functions.getFunctionCode(func)
	local funcGlobals = func.__value.globals

	-- Check argument count
	local providedArgs = #safeArgs
	local requiredArgs = code.argcount
	local hasDefaults = func.__value.defaults and #(func.__value.defaults :: { any }) > 0
	local minArgs = hasDefaults and (requiredArgs - #(func.__value.defaults :: { any })) or requiredArgs

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

	-- Create locals with argument binding
	local locals: { [string]: any } = {}

	-- Bind positional arguments
	for i = 1, providedArgs do
		if i <= #code.varnames then
			local varnameList: { [number]: string } = code.varnames
			local varname = varnameList[i]
			if varname then
				locals[varname] = safeArgs[i]
			end
		end
	end

	-- Apply default values for missing arguments
	if hasDefaults then
		local defaults = func.__value.defaults :: { any }
		local defaultStart = requiredArgs - #defaults + 1
		for i = providedArgs + 1, requiredArgs do
			local defaultIndex = i - defaultStart + 1
			if defaultIndex > 0 and defaultIndex <= #defaults and i <= #code.varnames then
				local varnameList: { [number]: string } = code.varnames
				local varname = varnameList[i]
				if varname then
					locals[varname] = defaults[defaultIndex]
				end
			end
		end
	end

	-- Handle keyword arguments
	for name: string, value in pairs(safeKwargs) do
		-- Find the parameter index
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

	-- Execute function bytecode using a new frame
	local funcFrame = Frame.new(code.bytecode, funcGlobals, vm.builtins, locals, code.name)

	-- Save current frame and push new frame
	local prevFrame = vm.current_frame
	vm.current_frame = funcFrame
	table.insert(vm.call_stack, funcFrame)

	-- Execute function bytecode
	while Frame.hasNext(funcFrame) do
		local instruction = Frame.getCurrentInstruction(funcFrame)
		if not instruction then
			break
		end

		local shouldContinue = executeInstruction(vm, funcFrame, instruction, code.constants, code.names)
		if not shouldContinue then
			break
		end

		-- Only advance if the instruction didn't handle jumping itself
		-- Jump instructions set a flag instead of returning true
		if not funcFrame.skip_advance then
			Frame.advance(funcFrame)
		else
			funcFrame.skip_advance = false -- Reset flag
		end
	end

	-- Restore previous frame
	table.remove(vm.call_stack)
	vm.current_frame = prevFrame

	-- Return the result or None if no explicit return
	local result = vm.return_value
	if result == nil then
		result = Base.newPyObject("NoneType", nil)
	end

	-- Clear return value for next function call
	vm.return_value = nil

	return result
end

-- Execute bytecode
function Interpreter.execute(
	code: { Instruction },
	globals: { [string]: any }?,
	builtins: { [string]: any }?,
	constants: { any }?,
	names: { string }?
): any
	local vm = Interpreter.newState(globals, builtins)
	local frame = Frame.new(code, vm.globals, vm.builtins)

	vm.current_frame = frame
	table.insert(vm.call_stack, frame)

	-- Main execution loop
	while Frame.hasNext(frame) do
		local instruction = Frame.getCurrentInstruction(frame)
		if not instruction then
			break
		end

		local shouldContinue = executeInstruction(vm, frame, instruction, constants, names)
		if not shouldContinue then
			break
		end

		-- Only advance if the instruction didn't handle jumping itself
		-- Jump instructions set a flag instead of returning true
		if not frame.skip_advance then
			Frame.advance(frame)
		else
			frame.skip_advance = false -- Reset flag
		end
	end

	-- Unwrap return value for external boundary
	local ret = unwrapPrimitive(vm.return_value)

	-- Normalize globals for external observation: unwrap primitive PyObjects
	for k, v in pairs(vm.globals) do
		vm.globals[k] = unwrapPrimitive(v)
	end

	return ret
end

-- Execute with timeout (for future safety)
function Interpreter.executeWithTimeout(
	code: { Instruction },
	globals: { [string]: any }?,
	builtins: { [string]: any }?,
	constants: { any }?,
	names: { string }?,
	timeout: number?
): any
	-- Simple implementation without actual timeout for now
	-- In a real implementation, this would use coroutines or step-by-step execution
	return Interpreter.execute(code, globals, builtins, constants, names)
end

return Interpreter
