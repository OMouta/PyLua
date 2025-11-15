local Base = {}

-- Forward declare types to allow mutual references
export type PyType = {
	__name: string,
	methods: { [string]: (self: PyObject, args: { PyObject }?) -> PyObject }?,
	__getattr: ((self: PyObject, name: string) -> PyObject?)?,
	__setattr: ((self: PyObject, name: string, value: PyObject) -> ())?,
	bases: { PyType }?,
	attributes: { [string]: PyObject }?,
	isUserDefined: boolean?,
}

export type PyObject = {
	__type: string, -- Python type name (mirrors __typeobj.__name)
	__value: any, -- Underlying Luau value
	__dict: { [string]: PyObject }?, -- Instance attributes
	__typeobj: PyType, -- Reference to its type descriptor
}

-- Bound method wrapper (very small representation)
export type PyBoundMethod = PyObject & {
	__type: "builtin_function_or_method",
	__value: {
		self: PyObject,
		name: string,
		func: (self: PyObject, args: { PyObject }?) -> PyObject,
		owner: PyType?,
	},
}

export type PyPythonBoundMethod = PyObject & {
	__type: "bound_method",
	__value: {
		self: PyObject,
		func: PyObject,
		owner: PyType?,
	},
}

type TypeSpec = {
	methods: { [string]: (self: PyObject, args: { PyObject }?) -> PyObject }?,
	__getattr: ((self: PyObject, name: string) -> PyObject?)?,
	__setattr: ((self: PyObject, name: string, value: PyObject) -> ())?,
	bases: { PyType }?,
	attributes: { [string]: PyObject }?,
	isUserDefined: boolean?,
}

-- Internal registry of types
local typeRegistry: { [string]: PyType } = {}

type PythonCallHelper = (vm: any, func: any, args: { PyObject }?, kwargs: { [string]: PyObject }?) -> PyObject

local pythonCallHelper: PythonCallHelper? = nil
local activeVM: any? = nil

-- Primitive singletons (mirrors CPython behavior for None/bool)
local noneSingleton: PyObject?
local boolSingletons: { [boolean]: PyObject } = {}

local function ensurePrimitiveSingletons()
	if not noneSingleton then
		noneSingleton = Base.newPyObject("NoneType", nil)
	end
	if not boolSingletons[true] then
		boolSingletons[true] = Base.newPyObject("bool", true)
	end
	if not boolSingletons[false] then
		boolSingletons[false] = Base.newPyObject("bool", false)
	end
end

-- Utility helpers

local function isPyObject(v: any): boolean
	return type(v) == "table" and v.__type ~= nil and v.__typeobj ~= nil
end

function Base.setPythonCallHelper(helper: PythonCallHelper)
	pythonCallHelper = helper
end

function Base.setActiveVM(vm: any?)
	activeVM = vm
end

local function requirePythonCallContext(): (PythonCallHelper, any)
	if not pythonCallHelper or not activeVM then
		error("Python call context not configured", 2)
	end
	return pythonCallHelper, activeVM
end

-- Wrap raw Luau value into a PyObject with inferred type
function Base.ensurePyObject(value: any): PyObject
	if isPyObject(value) then
		return value :: PyObject
	end

	local inferred: string
	local luauType = type(value)
	if luauType == "number" then
		if value % 1 == 0 then
			inferred = "int"
		else
			inferred = "float"
		end
	elseif luauType == "string" then
		inferred = "str"
	elseif luauType == "boolean" then
		ensurePrimitiveSingletons()
		return boolSingletons[value]
	elseif luauType == "nil" then
		ensurePrimitiveSingletons()
		return noneSingleton :: PyObject
	else
		inferred = "object"
	end
	return Base.newPyObject(inferred, value)
end

function Base.toLuau(obj: PyObject): any
	return obj.__value
end

-- Type registration / lookup

function Base.registerType(name: string, spec: TypeSpec?): PyType
	if typeRegistry[name] then
		error("Type already registered: " .. name, 2)
	end
	local t: PyType = {
		__name = name,
		methods = if spec and spec.methods then spec.methods else {},
		__getattr = if spec and spec.__getattr then spec.__getattr else nil,
		__setattr = if spec and spec.__setattr then spec.__setattr else nil,
		bases = spec and spec.bases or nil,
		attributes = if spec and spec.attributes then spec.attributes else {},
		isUserDefined = spec and spec.isUserDefined or false,
	}
	typeRegistry[name] = t
	return t
end

function Base.getTypeObject(name: string): PyType
	local t = typeRegistry[name]
	if not t then
		error("Unknown type: " .. name, 2)
	end
	return t
end

local function ensureTypeAttributes(pyType: PyType): { [string]: PyObject }
	if not pyType.attributes then
		pyType.attributes = {}
	end
	return pyType.attributes :: { [string]: PyObject }
end

local function lookupAttribute(pyType: PyType?, name: string): (any, string?, PyType?)
	if not pyType then
		return nil, nil, nil
	end
	if pyType.attributes and pyType.attributes[name] ~= nil then
		return pyType.attributes[name], "pyobject", pyType
	end
	if pyType.methods and pyType.methods[name] then
		return pyType.methods[name], "builtin", pyType
	end
	if pyType.bases then
		for _, baseType in ipairs(pyType.bases) do
			local value, kind, owner = lookupAttribute(baseType, name)
			if value ~= nil then
				return value, kind, owner
			end
		end
	end
	return nil, nil, nil
end

local function bindBuiltinMethod(instance: PyObject, name: string, func: (PyObject, { PyObject }?) -> PyObject, owner: PyType?): PyBoundMethod
	local builtinType = typeRegistry["builtin_function_or_method"]
		or Base.registerType("builtin_function_or_method", {})
	local boundAny: any = {
		__type = "builtin_function_or_method",
		__value = {
			self = instance,
			name = name,
			func = func,
			owner = owner,
		},
		__dict = {},
		__typeobj = builtinType,
	}
	return boundAny :: PyBoundMethod
end

local function bindPythonMethod(instance: PyObject, func: PyObject, owner: PyType?): PyPythonBoundMethod
	local boundType = typeRegistry["bound_method"] or Base.registerType("bound_method", {})
	local boundAny: any = {
		__type = "bound_method",
		__value = {
			self = instance,
			func = func,
			owner = owner,
		},
		__dict = {},
		__typeobj = boundType,
	}
	return boundAny :: PyPythonBoundMethod
end

local function tryClassAttribute(obj: PyObject, name: string): PyObject?
	if obj.__type ~= "type" then
		return nil
	end
	local dict = obj.__dict
	if dict and dict[name] then
		return dict[name]
	end
	local meta = obj.__value
	if type(meta) == "table" then
		local pyType = (meta :: any).pyType
		if pyType then
			local attr, kind = lookupAttribute(pyType, name)
			if attr ~= nil and kind == "pyobject" then
				return attr :: PyObject
			end
		end
	end
	return nil
end

function Base.newClass(name: string, bases: { PyType }, attributes: { [string]: PyObject }): PyObject
	local normalizedBases = if #bases > 0 then bases else nil
	local attrCopy: { [string]: PyObject } = {}
	for key, value in pairs(attributes) do
		attrCopy[key] = value
	end
	local pyType: PyType = {
		__name = name,
		methods = {},
		__getattr = nil,
		__setattr = nil,
		bases = normalizedBases,
		attributes = attrCopy,
		isUserDefined = true,
	}
	typeRegistry[name] = pyType
	local typeType = typeRegistry["type"] or Base.registerType("type", {})
	for _, value in pairs(attrCopy) do
		if type(value) == "table" and value.__type == "function" then
			local info = value.__value
			if type(info) == "table" then
				(info :: any).owner = pyType
			end
		end
	end
	local classObj: PyObject = {
		__type = "type",
		__value = {
			name = name,
			pyType = pyType,
			bases = normalizedBases,
		},
		__dict = attrCopy,
		__typeobj = typeType,
	}
	return classObj
end

function Base.wrapType(pyType: PyType): PyObject
	local typeType = typeRegistry["type"] or Base.registerType("type", {})
	local dict = ensureTypeAttributes(pyType)
	local classObj: PyObject = {
		__type = "type",
		__value = {
			name = pyType.__name,
			pyType = pyType,
			bases = pyType.bases,
		},
		__dict = dict,
		__typeobj = typeType,
	}
	return classObj
end

-- Object creation

function Base.newPyObject(typeName: string, value: any): PyObject
	local t = typeRegistry[typeName]
	if not t then
		-- Lazy auto-register primitive if missing (helps bootstrapping)
		t = Base.registerType(typeName, {})
	end
	local obj: PyObject = {
		__type = t.__name,
		__value = value,
		__dict = {},
		__typeobj = t,
	}
	return obj
end

function Base.newInstance(pyType: PyType): PyObject
	local obj: PyObject = {
		__type = pyType.__name,
		__value = {},
		__dict = {},
		__typeobj = pyType,
	}
	return obj
end

-- Convenience constructors (explicit typing beats heuristic inference)
function Base.newInt(n: number): PyObject
	return Base.newPyObject("int", n)
end

function Base.newFloat(n: number): PyObject
	return Base.newPyObject("float", n)
end

function Base.newBool(value: boolean): PyObject
	ensurePrimitiveSingletons()
	return boolSingletons[value]
end

function Base.newNone(): PyObject
	ensurePrimitiveSingletons()
	return noneSingleton :: PyObject
end

-- Bytes constructor: accepts string or table of numbers (0-255)
function Base.newBytes(val: any): PyObject
	if type(val) == "string" then
		-- Store as string, but validate all bytes are in 0-255
		for i = 1, #val do
			local b = string.byte(val, i)
			if not b or b < 0 or b > 255 then
				error("ValueError: bytes() string contains non-byte value", 2)
			end
		end
		return Base.newPyObject("bytes", val)
	elseif type(val) == "table" then
		local out = table.create(#val)
		for i, v in ipairs(val) do
			if type(v) ~= "number" or v < 0 or v > 255 or v % 1 ~= 0 then
				error("ValueError: bytes() table must contain integers in 0..255", 2)
			end
			out[i] = string.char(v)
		end
		return Base.newPyObject("bytes", table.concat(out, ""))
	elseif val == nil then
		return Base.newPyObject("bytes", "")
	else
		error("TypeError: bytes() argument must be string, table, or nil", 2)
	end
end

-- Attribute access / method resolution

-- Core getattr semantics (simplified subset of Python):
-- 1. Instance dict
-- 2. Type methods table => produce bound method wrapper
-- 3. Type custom __getattr hook
function Base.getattr(obj: PyObject, name: string): PyObject
	local classAttr = tryClassAttribute(obj, name)
	if classAttr then
		return classAttr
	end

	local dict = obj.__dict
	if dict and dict[name] then
		return dict[name]
	end

	local value, kind, ownerType = lookupAttribute(obj.__typeobj, name)
	if value ~= nil then
		if kind == "builtin" then
			return bindBuiltinMethod(
				obj,
				name,
				value :: (PyObject, { PyObject }?) -> PyObject,
				ownerType or obj.__typeobj
			)
		else
			local attrObj = value :: PyObject
			if attrObj.__type == "function" then
				return bindPythonMethod(obj, attrObj, ownerType or obj.__typeobj)
			end
			return attrObj
		end
	end

	local t = obj.__typeobj
	if t.__getattr then
		local dynamic = t.__getattr(obj, name)
		if dynamic then
			return dynamic
		end
	end
	error("AttributeError: object of type '" .. obj.__type .. "' has no attribute '" .. name .. "'", 2)
end

function Base.hasattr(obj: PyObject, name: string): boolean
	local ok = pcall(function()
		Base.getattr(obj, name)
	end)
	return ok
end

function Base.setattr(obj: PyObject, name: string, value: PyObject)
	if not isPyObject(value) then
		value = Base.ensurePyObject(value)
	end
	if obj.__type == "type" then
		local dict = obj.__dict
		if not dict then
			dict = {}
			obj.__dict = dict
		end
		(dict :: { [string]: PyObject })[name] = value
		local meta = obj.__value
		if type(meta) == "table" then
			local pyType = (meta :: any).pyType
			if pyType then
				local attrs = ensureTypeAttributes(pyType)
				attrs[name] = value
			end
		end
		return
	end
	local t = obj.__typeobj
	if t.__setattr then
		t.__setattr(obj, name, value)
		return
	end
	local dict = obj.__dict
	if not dict then
		dict = {}
		obj.__dict = dict
	end
	(dict :: { [string]: PyObject })[name] = value
end

-- Call a bound method or callable PyObject
function Base.call(callable: PyObject, args: { PyObject }?): PyObject
	local provided = args or {}
	local callArgs = provided :: { PyObject }
	if callable.__type == "builtin_function_or_method" then
		local inner = (callable :: PyBoundMethod).__value
		return inner.func(inner.self, callArgs)
	elseif callable.__type == "bound_method" then
		local helper, vm = requirePythonCallContext()
		local inner = (callable :: PyPythonBoundMethod).__value
		local ordered = table.create(#callArgs + 1)
		ordered[1] = inner.self
		for i, arg in ipairs(callArgs) do
			ordered[i + 1] = arg
		end
		return helper(vm, inner.func, ordered, {})
	elseif callable.__type == "function" then
		local helper, vm = requirePythonCallContext()
		return helper(vm, callable, callArgs, {})
	end
	error("TypeError: object of type '" .. callable.__type .. "' is not callable", 2)
end

-- Operator / protocol helpers (initial subset)

local opNameMap: { [string]: string } = {
	add = "__add__",
	sub = "__sub__",
	mul = "__mul__",
	truediv = "__truediv__",
	floordiv = "__floordiv__",
	mod = "__mod__",
	pow = "__pow__",
	neg = "__neg__",
	pos = "__pos__",
	matmul = "__matmul__",
}

function Base.operate(op: string, left: PyObject, right: PyObject): PyObject
	local dunder = opNameMap[op]
	if not dunder then
		error("Unsupported operator: " .. op, 2)
	end
	-- Try left.__op__(right)
	local okLeft, method = pcall(function()
		return Base.getattr(left, dunder)
	end)
	if okLeft then
		return Base.call(method, { right })
	end
	-- Try right.__rop__(left)
	local rdunder = string.gsub(dunder, "__", "__r", 1) -- __add__ -> __radd__
	local okRight, rmethod = pcall(function()
		return Base.getattr(right, rdunder)
	end)
	if okRight then
		return Base.call(rmethod, { left })
	end
	error(
		"TypeError: unsupported operand type(s) for " .. op .. ": '" .. left.__type .. "' and '" .. right.__type .. "'",
		2
	)
end

function Base.unary(op: string, obj: PyObject): PyObject
	local dunder = opNameMap[op]
	if not dunder then
		error("Unsupported unary operator: " .. op, 2)
	end
	local ok, method = pcall(function()
		return Base.getattr(obj, dunder)
	end)
	if ok then
		return Base.call(method, {})
	end
	error("TypeError: bad operand type for unary '" .. op .. "': '" .. obj.__type .. "'", 2)
end

function Base.truthy(obj: PyObject): boolean
	local t = obj.__type
	if t == "NoneType" then
		return false
	elseif t == "bool" then
		return obj.__value == true
	elseif t == "int" or t == "float" then
		local num: number = obj.__value
		return num ~= 0
	elseif t == "str" then
		return (obj.__value :: any) ~= ""
	elseif t == "bytes" then
		return #(obj.__value :: string) > 0
	elseif t == "list" or t == "tuple" then
		return #(obj.__value :: { PyObject }) > 0
	elseif t == "dict" or t == "set" then
		for _ in pairs(obj.__value) do
			return true
		end
		return false
	end
	-- Collections will be added later (empty -> false)
	return true
end

-- Primitive / bootstrap types

local function bootstrap()
	local objectType = Base.registerType("object", {})
	local intType = Base.registerType("int", { bases = { objectType } })
	Base.registerType("float", { bases = { objectType } })
	Base.registerType("str", { bases = { objectType } })
	Base.registerType("bool", { bases = { intType } })
	Base.registerType("NoneType", { bases = { objectType } })
	Base.registerType("bytes", { bases = { objectType } })
	Base.registerType("type", { bases = { objectType } })
	Base.registerType("builtin_function_or_method", { bases = { objectType } })
	Base.registerType("bound_method", { bases = { objectType } })
	return objectType
end

bootstrap()

-- Introspection helpers

function Base.getType(obj: PyObject): string
	return obj.__type
end

function Base.getValue(obj: PyObject): any
	return obj.__value
end

function Base.typeRegistrySnapshot(): { [string]: boolean }
	local snap: { [string]: boolean } = {}
	for name, _ in pairs(typeRegistry) do
		snap[name] = true
	end
	return snap
end

function Base.lookupAttributeOnType(pyType: PyType, name: string): (any, string?, PyType?)
	return lookupAttribute(pyType, name)
end

local function buildMroRecursive(pyType: PyType, out: { PyType }, seen: { [PyType]: boolean })
	if seen[pyType] then
		return
	end
	seen[pyType] = true
	out[#out + 1] = pyType
	if pyType.bases then
		for _, baseType in ipairs(pyType.bases) do
			buildMroRecursive(baseType, out, seen)
		end
	end
end

function Base.computeMro(pyType: PyType): { PyType }
	local linearized: { PyType } = {}
	buildMroRecursive(pyType, linearized, {})
	return linearized
end

function Base.bindPythonMethod(instance: PyObject, func: PyObject, owner: PyType?): PyPythonBoundMethod
	return bindPythonMethod(instance, func, owner)
end

function Base.bindBuiltinMethod(instance: PyObject, name: string, func: (PyObject, { PyObject }?) -> PyObject, owner: PyType?): PyBoundMethod
	return bindBuiltinMethod(instance, name, func, owner)
end

function Base.getActiveFrame()
	if not activeVM then
		return nil
	end
	return activeVM.current_frame
end

return Base
