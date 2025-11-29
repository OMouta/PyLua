local Bridge = {}

local Base = require("../objects/base")
local Collections = require("../objects/collections")

type PyObject = Base.PyObject
type PyType = Base.PyType

type VisitedPy = { [PyObject]: any }
type VisitedLuau = { [any]: PyObject }

type HashEntry = { key: PyObject, value: PyObject }

type LuauFunctionRecord = { func: (...any) -> any }

type ClassBindingOptionsInternal = {
	pyTypeName: string,
	typeofName: string?,
	predicate: ((value: any) -> boolean)?,
	bindSelf: boolean?,
	getAttr: ((target: any, attr: string) -> any?)?,
	setAttr: ((target: any, attr: string, value: any) -> ())?,
	toLuau: ((target: any, visited: VisitedPy) -> any)?,
}

type ClassBinding = {
	pyTypeName: string,
	typeofName: string?,
	predicate: ((value: any) -> boolean)?,
	bindSelf: boolean,
	getAttr: ((target: any, attr: string) -> any?)?,
	setAttr: ((target: any, attr: string, value: any) -> ())?,
	toLuau: ((target: any, visited: VisitedPy) -> any)?,
}

type BindingPayload = {
	__pylua_binding: boolean,
	target: any,
	binding: ClassBinding,
}

export type ClassBindingOptions = ClassBindingOptionsInternal

local luauFunctionType: PyType?
local classBindings: { ClassBinding } = {}
local bindingByPyType: { [string]: ClassBinding } = {}

local bindingGetAttr: (PyObject, string) -> PyObject?
local bindingSetAttr: (PyObject, string, PyObject) -> ()

local function tryTypeof(value: any): string?
	local globalEnv = _G :: any
	local typeofFn = globalEnv and globalEnv.typeof
	if typeofFn and type(typeofFn) == "function" then
		local ok, result = pcall(typeofFn, value)
		if ok and type(result) == "string" then
			return result
		end
	end
	return nil
end

local function getTypeTag(value: any): string
	local tag = tryTypeof(value)
	if tag then
		return tag
	end
	return type(value)
end

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

local function bindingMatches(binding: ClassBinding, value: any): boolean
	if binding.typeofName then
		if getTypeTag(value) ~= binding.typeofName then
			return false
		end
	end
	if binding.predicate then
		local ok, result = pcall(binding.predicate, value)
		if not ok then
			return false
		end
		return result == true
	end
	return true
end

local function safeIndex(target: any, key: string): any?
	local ok, result = pcall(function()
		return target[key]
	end)
	if ok then
		return result
	end
	return nil
end

local function safeAssign(target: any, key: string, value: any)
	local ok, err = pcall(function()
		target[key] = value
	end)
	if not ok then
		error("AttributeError: cannot set attribute '" .. key .. "': " .. tostring(err), 2)
	end
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
				error(result, 0)
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

bindingGetAttr = function(obj: PyObject, attr: string): PyObject?
	local payloadRaw = obj.__value
	if type(payloadRaw) ~= "table" then
		return nil
	end
	local payload = payloadRaw :: BindingPayload
	local binding = payload.binding
	if not binding then
		return nil
	end
	local rawValue: any?
	if binding.getAttr then
		local ok, result = pcall(binding.getAttr, payload.target, attr)
		if ok then
			rawValue = result
		else
			rawValue = nil
		end
	end
	if rawValue == nil then
		rawValue = safeIndex(payload.target, attr)
	end
	if rawValue == nil then
		return nil
	end
	if isPyObject(rawValue) then
		return rawValue :: PyObject
	end
	if type(rawValue) == "function" then
		local method = rawValue
		local callFn: (...any) -> any
		if binding.bindSelf then
			callFn = function(...: any): any
				return method(payload.target, ...)
			end
		else
			callFn = method
		end
		return Bridge.wrapLuauFunction(callFn)
	end
	return Bridge.luauToPy(rawValue)
end

bindingSetAttr = function(obj: PyObject, attr: string, value: PyObject)
	local payloadRaw = obj.__value
	if type(payloadRaw) ~= "table" then
		error("AttributeError: cannot set attribute on unbound object", 2)
	end
	local payload = payloadRaw :: BindingPayload
	local binding = payload.binding
	if not binding then
		error("AttributeError: cannot set attribute on unbound object", 2)
	end
	local luauValue = Bridge.pyToLuau(value)
	if binding.setAttr then
		local ok, errMsg = pcall(function()
			binding.setAttr(payload.target, attr, luauValue)
		end)
		if not ok then
			error(errMsg, 2)
		end
	else
		safeAssign(payload.target, attr, luauValue)
	end
end

local function ensureBindingType(binding: ClassBinding): PyType
	local ok, existing = pcall(function(): PyType
		return Base.getTypeObject(binding.pyTypeName)
	end)
	local typeObj: PyType
	if ok and existing then
		typeObj = existing
	else
		typeObj = Base.registerType(binding.pyTypeName, {})
	end
	typeObj.__getattr = bindingGetAttr
	typeObj.__setattr = bindingSetAttr
	typeObj.methods = typeObj.methods or {}
	return typeObj
end

local function createBindingInstance(value: any, visited: VisitedLuau, binding: ClassBinding): PyObject
	local existing = visited[value]
	if existing then
		return existing
	end
	ensureBindingType(binding)
	local payload: BindingPayload = {
		__pylua_binding = true,
		target = value,
		binding = binding,
	}
	local wrapper = Base.newPyObject(binding.pyTypeName, payload)
	visited[value] = wrapper
	return wrapper
end

local function tryClassBinding(value: any, visited: VisitedLuau): PyObject?
	if isPyObject(value) then
		return nil
	end
	for _, binding in ipairs(classBindings) do
		if bindingMatches(binding, value) then
			return createBindingInstance(value, visited, binding)
		end
	end
	return nil
end

function Bridge.registerClassBinding(options: ClassBindingOptionsInternal)
	if type(options) ~= "table" then
		error("registerClassBinding requires options table", 2)
	end
	local pyTypeName = options.pyTypeName
	if type(pyTypeName) ~= "string" or pyTypeName == "" then
		error("registerClassBinding requires pyTypeName", 2)
	end
	if options.typeofName == nil and options.predicate == nil then
		error("registerClassBinding requires typeofName or predicate", 2)
	end
	local bindSelf = if options.bindSelf ~= nil then options.bindSelf else true
	local existing = bindingByPyType[pyTypeName]
	local binding: ClassBinding
	if existing then
		existing.typeofName = options.typeofName
		existing.predicate = options.predicate
		existing.bindSelf = bindSelf
		existing.getAttr = options.getAttr
		existing.setAttr = options.setAttr
		existing.toLuau = options.toLuau
		binding = existing
	else
		binding = {
			pyTypeName = pyTypeName,
			typeofName = options.typeofName,
			predicate = options.predicate,
			bindSelf = bindSelf,
			getAttr = options.getAttr,
			setAttr = options.setAttr,
			toLuau = options.toLuau,
		}
		bindingByPyType[pyTypeName] = binding
		classBindings[#classBindings + 1] = binding
	end
	ensureBindingType(binding)
	return binding
end

function Bridge.clearClassBindings()
	for index = #classBindings, 1, -1 do
		classBindings[index] = nil
	end
	for key in pairs(bindingByPyType) do
		bindingByPyType[key] = nil
	end
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
		local bindingWrapper = tryClassBinding(value, visited)
		if bindingWrapper then
			return bindingWrapper
		end
		return Base.newPyObject("object", value)
	end

	if isPyObject(value) then
		return value
	end

	if value.__nil then
		return Base.newNone()
	end

	local bindingWrapper = tryClassBinding(value, visited)
	if bindingWrapper then
		return bindingWrapper
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
	elseif type(obj.__value) == "table" and (obj.__value :: any).__pylua_binding then
		local payload = obj.__value :: BindingPayload
		local binding = payload.binding
		if binding.toLuau then
			visited[obj] = payload.target
			local converted = binding.toLuau(payload.target, visited)
			visited[obj] = converted
			return converted
		end
		visited[obj] = payload.target
		return payload.target
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
