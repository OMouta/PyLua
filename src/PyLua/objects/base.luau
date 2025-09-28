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
	},
}

-- Internal registry of types
local typeRegistry: { [string]: PyType } = {}

-- Utility helpers

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

-- Type registration / lookup

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

-- Convenience constructors (explicit typing beats heuristic inference)
function Base.newInt(n: number): PyObject
	return Base.newPyObject("int", n)
end

function Base.newFloat(n: number): PyObject
	return Base.newPyObject("float", n)
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
		local builtinType = typeRegistry["builtin_function_or_method"]
			or Base.registerType("builtin_function_or_method", {})
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
	-- Primitive placeholder methods can be added later
	Base.registerType("int", {})
	Base.registerType("float", {})
	Base.registerType("str", {})
	Base.registerType("bool", {})
	Base.registerType("NoneType", {})
	Base.registerType("bytes", {})
	-- meta for builtins
	Base.registerType("builtin_function_or_method", {})
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

return Base
