--!strict
-- PyLua Built-in Types
-- Phase 3 - Python built-in type implementations

local Builtins = {}

local base = require("./base")
type PyObject = base.PyObject

-- Forward references to type registration already performed in base bootstrap

-- None -----------------------------------------------------------------
export type PyNone = PyObject & { __type: "NoneType", __value: nil }
local NONE_SINGLETON: PyNone = base.newPyObject("NoneType", nil) :: PyNone

function Builtins.None(): PyNone
	return NONE_SINGLETON
end

-- Booleans --------------------------------------------------------------
export type PyBool = PyObject & { __type: "bool", __value: boolean }

function Builtins.True(): PyBool
	return base.newPyObject("bool", true) :: PyBool
end

function Builtins.False(): PyBool
	return base.newPyObject("bool", false) :: PyBool
end

-- Numbers ---------------------------------------------------------------
export type PyInt = PyObject & { __type: "int", __value: number }
export type PyFloat = PyObject & { __type: "float", __value: number }

function Builtins.Int(n: number): PyInt
	if n % 1 ~= 0 then
		error("Int() requires integral value", 2)
	end
	return base.newInt(n) :: PyInt
end

function Builtins.Float(n: number): PyFloat
	return base.newFloat(n) :: PyFloat
end

export type PyStr = PyObject & { __type: "str", __value: string }

function Builtins.Str(s: string): PyStr
	return base.newPyObject("str", s) :: PyStr
end

-- Bytes ---------------------------------------------------------------
export type PyBytes = PyObject & { __type: "bytes", __value: string }

function Builtins.Bytes(val: any): PyBytes
	return base.newBytes(val) :: PyBytes
end

-- Minimal bytes operations (repr, eq, len, getitem)
local getTypeObject = (base :: any).getTypeObject
local bytesType = getTypeObject("bytes")
bytesType.methods = bytesType.methods or {}

-- __repr__
bytesType.methods["__repr__"] = function(selfObj: PyObject)
	local s = selfObj.__value :: string
	local out = {"b'"}
	for i = 1, #s do
		local b = string.byte(s, i)
		if b >= 32 and b <= 126 and b ~= 39 and b ~= 92 then -- printable, not ' or \
			table.insert(out, string.char(b))
		elseif b == 39 then
			table.insert(out, "\\'")
		elseif b == 92 then
			table.insert(out, "\\\\")
		else
			table.insert(out, string.format("\\x%02x", b))
		end
	end
	table.insert(out, "'")
	return base.newPyObject("str", table.concat(out, ""))
end

-- __eq__
bytesType.methods["__eq__"] = function(selfObj: PyObject, args: { PyObject }?)
	local other = args and args[1]
	if not other or other.__type ~= "bytes" then
		return base.newPyObject("bool", false)
	end
	return base.newPyObject("bool", selfObj.__value == other.__value)
end

-- __len__
bytesType.methods["__len__"] = function(selfObj: PyObject)
	return base.newPyObject("int", #(selfObj.__value :: string))
end

-- __getitem__ (indexing)
bytesType.methods["__getitem__"] = function(selfObj: PyObject, args: { PyObject }?)
	local idx = args and args[1]
	if not idx or (idx.__type ~= "int" and idx.__type ~= "float") then
		error("TypeError: bytes indices must be integers", 2)
	end
	local i = idx.__value
	if i < 0 then
		i = #(selfObj.__value) + i + 1
	else
		i = i + 1 -- Python is 0-based, Luau is 1-based
	end
	if i < 1 or i > #(selfObj.__value) then
		error("IndexError: bytes index out of range", 2)
	end
	local b = string.byte(selfObj.__value, i)
	return base.newPyObject("int", b)
end

-- __add__ (concatenate)
bytesType.methods["__add__"] = function(selfObj: PyObject, args: { PyObject }?)
	local other = args and args[1]
	if not other or other.__type ~= "bytes" then
		error("TypeError: can't concat bytes to non-bytes", 2)
	end
	return base.newPyObject("bytes", (selfObj.__value :: string) .. (other.__value :: string))
end

-- __mul__ (repeat)
bytesType.methods["__mul__"] = function(selfObj: PyObject, args: { PyObject }?)
	local nObj = args and args[1]
	if not nObj or nObj.__type ~= "int" then
		error("TypeError: can't multiply sequence by non-int", 2)
	end
	local n: number = nObj.__value
	if n <= 0 then
		return base.newPyObject("bytes", "")
	end
	local pieces = table.create(n)
	for i = 1, n do pieces[i] = selfObj.__value end
	return base.newPyObject("bytes", table.concat(pieces, ""))
end

-- Type objects (very small placeholder) --------------------------------
export type PyTypeObj = PyObject & { __type: "type", __value: { name: string } }

local function _makeTypeObject(name: string): PyTypeObj
	return base.newPyObject("type", { name = name }) :: PyTypeObj
end

-- Arithmetic method attachments (monkey patch into registered types)
local function attachPrimitiveMethods()
	local function wrapNum(result: number, left: PyObject, right: PyObject?): PyObject
		-- Preserve float if any operand is float
		if left.__type == "float" or (right and right.__type == "float") then
			return base.newFloat(result)
		end
		-- If non-integer result from int op -> float
		if result % 1 ~= 0 then
			return base.newFloat(result)
		end
		return base.newInt(result)
	end

	local registry = base.typeRegistrySnapshot()
	if registry.int then
		-- We can't mutate type tables directly from snapshot; fetch actual via internal API.
		-- Using protected access: base.getTypeObject (not exported earlier, but present).
		local getTypeObject = (base :: any).getTypeObject
		local intType = getTypeObject("int")
		local floatType = getTypeObject("float")
		local strType = getTypeObject("str")

		intType.methods = intType.methods or {}
		floatType.methods = floatType.methods or {}
		strType.methods = strType.methods or {}

		local numAdd = function(selfObj: PyObject, args: { PyObject }?)
			local other = args and args[1] or base.ensurePyObject(0)
			if other.__type ~= "int" and other.__type ~= "float" then
				error("TypeError: unsupported operand type(s) for +", 2)
			end
			return wrapNum(selfObj.__value + other.__value, selfObj, other)
		end

		local numSub = function(selfObj: PyObject, args: { PyObject }?)
			local other = args and args[1] or base.ensurePyObject(0)
			if other.__type ~= "int" and other.__type ~= "float" then
				error("TypeError: unsupported operand type(s) for -", 2)
			end
			return wrapNum(selfObj.__value - other.__value, selfObj, other)
		end

		local numMul = function(selfObj: PyObject, args: { PyObject }?)
			local other = args and args[1] or base.ensurePyObject(0)
			if other.__type ~= "int" and other.__type ~= "float" then
				error("TypeError: unsupported operand type(s) for *", 2)
			end
			return wrapNum(selfObj.__value * other.__value, selfObj, other)
		end

		local numTrueDiv = function(selfObj: PyObject, args: { PyObject }?)
			local other = args and args[1] or base.ensurePyObject(1)
			if other.__value == 0 then
				error("ZeroDivisionError: division by zero", 2)
			end
			return base.newFloat(selfObj.__value / other.__value)
		end

		intType.methods["__add__"] = numAdd
		intType.methods["__sub__"] = numSub
		intType.methods["__mul__"] = numMul
		intType.methods["__truediv__"] = numTrueDiv
		floatType.methods["__add__"] = numAdd
		floatType.methods["__sub__"] = numSub
		floatType.methods["__mul__"] = numMul
		floatType.methods["__truediv__"] = numTrueDiv

		-- String concatenation & repetition minimal subset
		strType.methods["__add__"] = function(selfObj: PyObject, args: { PyObject }?)
			local other = args and args[1] or base.ensurePyObject("")
			if other.__type ~= "str" then
				error("TypeError: can only concatenate str (not '" .. other.__type .. "') to str", 2)
			end
			return base.newPyObject("str", (selfObj.__value :: any) .. (other.__value :: any))
		end
		strType.methods["__mul__"] = function(selfObj: PyObject, args: { PyObject }?)
			local other = args and args[1] or base.ensurePyObject(0)
			if other.__type ~= "int" then
				error("TypeError: can't multiply sequence by non-int", 2)
			end
			local n: number = other.__value
			if n < 0 then
				n = 0
			end
			local pieces = table.create(n)
			for i = 1, n do
				pieces[i] = selfObj.__value
			end
			return base.newPyObject("str", table.concat(pieces, ""))
		end
	end
end

attachPrimitiveMethods()

return Builtins
