-- NOTE: This is an initial skeleton of the PyObject system. It will be
-- extended in later Phase 3 sub‑tasks (protocols, numeric tower, etc.).

local Base = {}

-- Forward declare types to allow mutual references
export type PyType = {
	__name: string,
	methods: { [string]: (self: PyObject, args: { PyObject }?) -> PyObject }?,
	__getattr: ((self: PyObject, name: string) -> PyObject?)?,
	__setattr: ((self: PyObject, name: string, value: PyObject) -> ())?,
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
	}
}

-- Internal registry of types
local typeRegistry: { [string]: PyType } = {}

---------------------------------------------------------------------
-- Utility helpers
---------------------------------------------------------------------

local function isPyObject(v: any): boolean
	return type(v) == "table" and v.__type ~= nil and v.__typeobj ~= nil
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
		inferred = "bool"
	elseif luauType == "nil" then
		inferred = "NoneType"
	else
		inferred = "object"
	end
	return Base.newPyObject(inferred, value)
end

function Base.toLuau(obj: PyObject): any
	return obj.__value
end

---------------------------------------------------------------------
-- Type registration / lookup
---------------------------------------------------------------------

function Base.registerType(name: string, spec: { methods: { [string]: any }? }?): PyType
	if typeRegistry[name] then
		error("Type already registered: " .. name, 2)
	end
	local t: PyType = {
		__name = name,
		methods = if spec and spec.methods then spec.methods else {},
		__getattr = if spec and (spec :: any).__getattr then (spec :: any).__getattr else nil,
		__setattr = if spec and (spec :: any).__setattr then (spec :: any).__setattr else nil,
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

---------------------------------------------------------------------
-- Object creation
---------------------------------------------------------------------

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

-- Convenience constructors (explicit typing beats heuristic inference)
function Base.newInt(n: number): PyObject
	return Base.newPyObject("int", n)
end

function Base.newFloat(n: number): PyObject
	return Base.newPyObject("float", n)
end

---------------------------------------------------------------------
-- Attribute access / method resolution
---------------------------------------------------------------------

-- Core getattr semantics (simplified subset of Python):
-- 1. Instance dict
-- 2. Type methods table => produce bound method wrapper
-- 3. Type custom __getattr hook
function Base.getattr(obj: PyObject, name: string): PyObject
	-- Instance attribute (overrides type methods)
	local dict = obj.__dict
	if dict and dict[name] then
		return dict[name]
	end

	local t = obj.__typeobj
	local methods = t.methods
	if methods and methods[name] then
		local func = methods[name]
		-- Bind method to instance
		local builtinType = typeRegistry["builtin_function_or_method"] or Base.registerType("builtin_function_or_method", {})
		local boundAny: any = {
			__type = "builtin_function_or_method",
			__value = {
				self = obj,
				name = name,
				func = func,
			},
			__dict = {},
			__typeobj = builtinType,
		}
		return boundAny :: PyBoundMethod
	end

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
	(dict :: any)[name] = value
end

-- Call a bound method or callable PyObject
function Base.call(callable: PyObject, args: { PyObject }?): PyObject
	args = args or {}
	if callable.__type == "builtin_function_or_method" then
		local inner = (callable :: PyBoundMethod).__value
		return inner.func(inner.self, args)
	end
	error("TypeError: object of type '" .. callable.__type .. "' is not callable", 2)
end

---------------------------------------------------------------------
-- Primitive / bootstrap types
---------------------------------------------------------------------

local function bootstrap()
	local objectType = Base.registerType("object", {})
	-- Primitive placeholder methods can be added later
	Base.registerType("int", {})
	Base.registerType("float", {})
	Base.registerType("str", {})
	Base.registerType("bool", {})
	Base.registerType("NoneType", {})
	-- meta for builtins
	Base.registerType("builtin_function_or_method", {})
	return objectType
end

bootstrap()

---------------------------------------------------------------------
-- Introspection helpers
---------------------------------------------------------------------

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

return Base
