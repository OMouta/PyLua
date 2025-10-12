local Bridge = {}

local Base = require("../objects/base")
local Collections = require("../objects/collections")

type PyObject = Base.PyObject
type PyType = Base.PyType

type VisitedPy = { [PyObject]: any }
type VisitedLuau = { [any]: PyObject }

type HashEntry = { key: PyObject, value: PyObject }

type LuauFunctionRecord = { func: (...any) -> any }

local luauFunctionType: PyType?

local function isPyObject(value: any): boolean
	return type(value) == "table" and value.__type ~= nil and value.__typeobj ~= nil
end

local function isSequenceTable(tbl: { [any]: any }): boolean
	local maxIndex = 0
	local count = 0
	for key, _ in pairs(tbl) do
		if type(key) ~= "number" or key % 1 ~= 0 or key < 1 then
			return false
		end
		if key > maxIndex then
			maxIndex = key
		end
		count += 1
	end
	if count == 0 then
		return true
	end
	if maxIndex ~= count then
		return false
	end
	for i = 1, maxIndex do
		if rawget(tbl, i) == nil then
			return false
		end
	end
	return true
end

local function hashKey(obj: PyObject): string
	local t = obj.__type
	if t == "int" or t == "float" or t == "bool" or t == "str" then
		return t .. ":" .. tostring(obj.__value)
	elseif t == "NoneType" then
		return "None"
	end
	return tostring(obj)
end

local function ensureLuauFunctionType(): PyType
	if luauFunctionType then
		return luauFunctionType
	end
	local ok, existing = pcall(function(): PyType
		return Base.getTypeObject("luau_function")
	end)
	local typeObj: PyType
	if ok and existing then
		typeObj = existing
	else
		typeObj = Base.registerType("luau_function", {})
	end
	typeObj.methods = typeObj.methods or {}
	local methods = typeObj.methods :: { [string]: (PyObject, { PyObject }?) -> PyObject }
	if not methods["__call__"] then
		methods["__call__"] = function(selfObj: PyObject, args: { PyObject }?): PyObject
			local record: LuauFunctionRecord = selfObj.__value
			local converted: { any } = {}
			if args then
				for index, arg in ipairs(args) do
					converted[index] = Bridge.pyToLuau(arg)
				end
			end
			local okCall, result = pcall(record.func, table.unpack(converted))
			if not okCall then
				error(result, 2)
			end
			return Bridge.luauToPy(result)
		end
	end
	luauFunctionType = typeObj
	return typeObj
end

function Bridge.wrapLuauFunction(fn: (...any) -> any): PyObject
	if type(fn) ~= "function" then
		error("wrapLuauFunction requires a Luau function", 2)
	end
	local typeObj = ensureLuauFunctionType()
	local wrapper: PyObject = {
		__type = "luau_function",
		__value = { func = fn },
		__dict = {},
		__typeobj = typeObj,
	}
	return wrapper
end

local function luauToPyInternal(value: any, visited: VisitedLuau): PyObject
	local valueType = type(value)
	if valueType == "nil" then
		return Base.newNone()
	elseif valueType == "boolean" or valueType == "number" or valueType == "string" then
		return Base.ensurePyObject(value)
	elseif valueType == "function" then
		return Bridge.wrapLuauFunction(value)
	elseif valueType ~= "table" then
		return Base.newPyObject("object", value)
	end

	if isPyObject(value) then
		return value
	end

	if value.__nil then
		return Base.newNone()
	end

	if visited[value] then
		return visited[value]
	end

	if isSequenceTable(value) then
		local list = Collections.newList({})
		visited[value] = list
		local storage = list.__value :: { PyObject }
		local length = #value
		for index = 1, length do
			storage[index] = luauToPyInternal(value[index], visited)
		end
		return list
	end

	local dict = Collections.newDict({})
	visited[value] = dict
	local storage = dict.__value :: { [string]: HashEntry }
	for key, entryValue in pairs(value) do
		local pyKey = luauToPyInternal(key, visited)
		local pyValue = luauToPyInternal(entryValue, visited)
		storage[hashKey(pyKey)] = { key = pyKey, value = pyValue }
	end
	return dict
end

function Bridge.luauToPy(value: any): PyObject
	return luauToPyInternal(value, {})
end

local function pyToLuauInternal(obj: PyObject, visited: VisitedPy): any
	if visited[obj] ~= nil then
		return visited[obj]
	end

	local typeName = obj.__type
	if typeName == "NoneType" then
		return nil
	elseif typeName == "bool" then
		return obj.__value == true
	elseif typeName == "int" or typeName == "float" then
		return obj.__value
	elseif typeName == "str" or typeName == "bytes" then
		return obj.__value
	elseif typeName == "list" or typeName == "tuple" then
		local arr: { any } = {}
		visited[obj] = arr
		local source = obj.__value :: { PyObject }
		for index, item in ipairs(source) do
			arr[index] = pyToLuauInternal(item, visited)
		end
		return arr
	elseif typeName == "dict" then
		local tbl: { [any]: any } = {}
		visited[obj] = tbl
		local storage = obj.__value :: { [string]: HashEntry }
		for _, entry in pairs(storage) do
			local keyValue = pyToLuauInternal(entry.key, visited)
			local keyType = type(keyValue)
			if keyType ~= "string" and keyType ~= "number" and keyType ~= "boolean" then
				error("TypeError: unhashable type: '" .. entry.key.__type .. "'", 2)
			end
			tbl[keyValue] = pyToLuauInternal(entry.value, visited)
		end
		return tbl
	elseif typeName == "set" then
		local arr: { any } = {}
		visited[obj] = arr
		local storage = obj.__value :: { [string]: { value: PyObject } }
		local index = 1
		for _, entry in pairs(storage) do
			arr[index] = pyToLuauInternal(entry.value, visited)
			index += 1
		end
		return arr
	elseif typeName == "luau_function" then
		local record: LuauFunctionRecord = obj.__value
		return record.func
	end

	return obj.__value
end

function Bridge.pyToLuau(value: any): any
	local obj: PyObject
	if isPyObject(value) then
		obj = value
	else
		obj = Base.ensurePyObject(value)
	end
	return pyToLuauInternal(obj, {})
end

return Bridge
