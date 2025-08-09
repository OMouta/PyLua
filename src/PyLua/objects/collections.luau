--!strict
-- PyLua Collection Types
-- Phase 3.3 - Python collection implementations (initial subset)

local Collections = {}

local base = require("./base")
local builtins = require("./builtins")

type PyObject = base.PyObject
export type PyList = PyObject & { __type: "list", __value: { PyObject } }
export type PyTuple = PyObject & { __type: "tuple", __value: { PyObject } }
export type PyDict = PyObject & { __type: "dict", __value: { [string]: { key: PyObject, value: PyObject } } }
export type PySet = PyObject & { __type: "set", __value: { [string]: { value: PyObject } } }

-- Helper: create hash key for dict/set (primitive focus)
local function hashKey(obj: PyObject): string
	local t = obj.__type
	if t == "int" or t == "float" or t == "bool" or t == "str" then
		return t .. ":" .. tostring(obj.__value)
	elseif t == "NoneType" then
		return "None"
	end
	-- fallback to pointer identity string
	return tostring(obj)
end

-- Register collection types with base only once
local getTypeObject = (base :: any).getTypeObject
local function ensureType(name: string)
	local ok = pcall(function()
		getTypeObject(name)
	end)
	if not ok then
		base.registerType(name, {})
	end
end

ensureType("list")
ensureType("tuple")
ensureType("dict")
ensureType("set")
ensureType("list_iterator")

---------------------------------------------------------------------
-- List implementation
---------------------------------------------------------------------

function Collections.newList(values: { PyObject }?): PyList
	local arr: { PyObject } = {}
	if values then
		for i, v in ipairs(values) do
			arr[i] = base.ensurePyObject(v)
		end
	end
	local obj = base.newPyObject("list", arr) :: PyList
	return obj
end

-- Attach methods to list type
do
	local listType = getTypeObject("list")
	listType.methods = listType.methods or {}
	listType.methods["append"] = function(selfObj: PyObject, args: { PyObject }?)
		local v = args and args[1]
		if not v then
			error("TypeError: append() missing value", 2)
		end
		table.insert(selfObj.__value, base.ensurePyObject(v))
		return builtins.None()
	end
	listType.methods["pop"] = function(selfObj: PyObject, args: { PyObject }?)
		local arr = selfObj.__value :: { PyObject }
		local idx = if args and args[1] then args[1].__value :: number else #arr
		if idx < 1 or idx > #arr then
			error("IndexError: pop index out of range", 2)
		end
		local val = table.remove(arr, idx)
		return val
	end
	listType.methods["__len__"] = function(selfObj: PyObject)
		return base.newInt(#(selfObj.__value :: { PyObject }))
	end
	listType.methods["__iter__"] = function(selfObj: PyObject)
		local iterState = { index = 0, list = selfObj }
		local iter = base.newPyObject("list_iterator", iterState)
		local iterType = getTypeObject("list_iterator")
		iterType.methods = iterType.methods or {}
		if not iterType.methods["__next__"] then
			iterType.methods["__next__"] = function(it: PyObject)
				local st = it.__value
				st.index += 1
				local arr = st.list.__value :: { PyObject }
				if st.index > #arr then
					error("StopIteration", 2)
				end
				return arr[st.index]
			end
		end
		return iter
	end
	-- Concatenation
	listType.methods["__add__"] = function(selfObj: PyObject, args: { PyObject }?)
		local other = args and args[1]
		if not other or other.__type ~= "list" then
			error("TypeError: can only concatenate list (not '" .. (other and other.__type or "nil") .. "') to list", 2)
		end
		local newArr: { PyObject } = {}
		for _, v in ipairs(selfObj.__value) do
			table.insert(newArr, v)
		end
		for _, v in ipairs(other.__value) do
			table.insert(newArr, v)
		end
		return Collections.newList(newArr)
	end
end

---------------------------------------------------------------------
-- Tuple implementation (immutable)
---------------------------------------------------------------------

function Collections.newTuple(values: { PyObject }?): PyTuple
	local arr: { PyObject } = {}
	if values then
		for i, v in ipairs(values) do
			arr[i] = base.ensurePyObject(v)
		end
	end
	local obj = base.newPyObject("tuple", arr) :: PyTuple
	return obj
end

do
	local tupleType = getTypeObject("tuple")
	tupleType.methods = tupleType.methods or {}
	tupleType.methods["__len__"] = function(selfObj: PyObject)
		return base.newInt(#(selfObj.__value :: { PyObject }))
	end
	tupleType.methods["__iter__"] = function(selfObj: PyObject)
		-- Reuse list iterator logic: fetch iterator method then call via base.call
		local listVersion: PyObject = Collections.newList(selfObj.__value)
		local iterMethod = base.getattr(listVersion, "__iter__")
		return base.call(iterMethod, {})
	end
end

---------------------------------------------------------------------
-- Dict implementation
---------------------------------------------------------------------

-- entries: array of two-element tables {key, value}
function Collections.newDict(entries: { { PyObject } }?): PyDict
	local storage: { [string]: { key: PyObject, value: PyObject } } = {}
	if entries then
		for _, pair in ipairs(entries) do
			local k = base.ensurePyObject(pair[1])
			local v = base.ensurePyObject(pair[2])
			storage[hashKey(k)] = { key = k, value = v }
		end
	end
	local obj = base.newPyObject("dict", storage) :: PyDict
	return obj
end

do
	local dictType = getTypeObject("dict")
	dictType.methods = dictType.methods or {}
	dictType.methods["set"] = function(selfObj: PyObject, args: { PyObject }?)
		if not args or #args < 2 then
			error("TypeError: set requires key and value", 2)
		end
		local k: PyObject = (args :: any)[1]
		local v: PyObject = (args :: any)[2]
		local store = selfObj.__value
		store[hashKey(k)] = { key = k, value = v }
		return builtins.None()
	end
	dictType.methods["get"] = function(selfObj: PyObject, args: { PyObject }?)
		if not args or #args < 1 then
			error("TypeError: get requires key", 2)
		end
		local k: PyObject = (args :: any)[1]
		local entry = (selfObj.__value :: any)[hashKey(k)]
		if entry then
			return entry.value
		end
		if args and (args :: any)[2] then
			return (args :: any)[2]
		end
		return builtins.None()
	end
	dictType.methods["__len__"] = function(selfObj: PyObject)
		local n = 0
		for _ in pairs(selfObj.__value) do
			n += 1
		end
		return base.newInt(n)
	end
end

---------------------------------------------------------------------
-- Set implementation
---------------------------------------------------------------------

function Collections.newSet(values: { PyObject }?): PySet
	local storage: { [string]: { value: PyObject } } = {}
	if values then
		for _, v in ipairs(values) do
			local pv = base.ensurePyObject(v)
			storage[hashKey(pv)] = { value = pv }
		end
	end
	local obj = base.newPyObject("set", storage) :: PySet
	return obj
end

do
	local setType = getTypeObject("set")
	setType.methods = setType.methods or {}
	setType.methods["add"] = function(selfObj: PyObject, args: { PyObject }?)
		local v = args and args[1]
		if not v then
			error("TypeError: add requires value", 2)
		end
		local pv = base.ensurePyObject(v)
		local store: any = selfObj.__value
		store[hashKey(pv)] = { value = pv }
		return builtins.None()
	end
	setType.methods["__len__"] = function(selfObj: PyObject)
		local n = 0
		for _ in pairs(selfObj.__value) do
			n += 1
		end
		return base.newInt(n)
	end
end

---------------------------------------------------------------------
-- Public API shortcuts
---------------------------------------------------------------------
Collections.list = Collections.newList
Collections.tuple = Collections.newTuple
Collections.dict = Collections.newDict
Collections.set = Collections.newSet

return Collections
