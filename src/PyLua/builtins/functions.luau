local Functions = {}

local base = require("../objects/base")
local obj_builtins = require("../objects/builtins")
local exceptions = require("./exceptions")

type PyObject = base.PyObject

-- Configurable writer for print (allows tests to capture output)
local defaultWriter = function(text: string)
	print(text)
end

Functions._writer = defaultWriter

function Functions.setWriter(writer: ((string) -> ())?)
	Functions._writer = writer or defaultWriter
end

local function ensurePy(obj: any): PyObject
	return base.ensurePyObject(obj)
end

local function pyToNumber(obj: PyObject, name: string, allowFloat: boolean?): number
	local t = obj.__type
	if t == "int" then
		return obj.__value
	elseif t == "float" then
		if allowFloat then
			return obj.__value
		end
		error("TypeError: '" .. name .. "' must be an integer", 3)
	elseif t == "bool" then
		return obj.__value and 1 or 0
	elseif t == "NoneType" then
		error("TypeError: '" .. name .. "' cannot be None", 3)
	else
		error("TypeError: '" .. name .. "' must be a number", 3)
	end
end

local function truncateTowardsZero(n: number): number
	if n >= 0 then
		return math.floor(n)
	else
		return math.ceil(n)
	end
end

local function pyBoolString(value: boolean): string
	return value and "True" or "False"
end

local function pyNoneString(): string
	return "None"
end

local objectRepr: (PyObject?) -> string

local function ensurePyTypeName(typeObj: PyObject): string
	local objType = typeObj.__type
	if objType == "type" then
		local info = typeObj.__value
		local name = if type(info) == "table" then (info :: any).name else nil
		if type(name) == "string" then
			return name
		end
	elseif objType == "builtin_function_or_method" then
		local inner = typeObj.__value
		local name = if type(inner) == "table" then (inner :: any).name else nil
		if type(name) == "string" then
			return name
		end
	end
	error("TypeError: isinstance() arg 2 has invalid type object", 3)
end

local function collectTypeNames(spec: PyObject, out: { string })
	local specType = spec.__type
	if specType == "tuple" then
		local elements = spec.__value :: { PyObject }
		for _, item in ipairs(elements) do
			collectTypeNames(item, out)
		end
	elseif specType == "type" or specType == "builtin_function_or_method" then
		local name = ensurePyTypeName(spec)
		out[#out + 1] = name
	else
		error("TypeError: isinstance() arg 2 must be a type or tuple of types", 3)
	end
end

local function tryRepr(obj: PyObject): string?
	local ok, reprMethod = pcall(function()
		return base.getattr(obj, "__repr__")
	end)
	if ok and reprMethod then
		local result = base.call(reprMethod, {})
		if result.__type == "str" then
			return result.__value
		end
	end
	return nil
end

local function pyToString(obj: PyObject): string
	local t = obj.__type
	if t == "str" then
		return obj.__value
	elseif t == "int" or t == "float" then
		return tostring(obj.__value)
	elseif t == "bool" then
		return pyBoolString(obj.__value)
	elseif t == "NoneType" then
		return pyNoneString()
	elseif t == "bytes" then
		return objectRepr(obj)
	else
		local ok, strMethod = pcall(function()
			return base.getattr(obj, "__str__")
		end)
		if ok and strMethod then
			local result = base.call(strMethod, {})
			if result.__type == "str" then
				return result.__value
			end
		end
		return objectRepr(obj)
	end
end

local function reprString(s: string): string
	local pieces = { "'" }
	for i = 1, #s do
		local ch = s:sub(i, i)
		if ch == "\\" then
			pieces[#pieces + 1] = "\\\\"
		elseif ch == "'" then
			pieces[#pieces + 1] = "\\'"
		elseif ch == "\n" then
			pieces[#pieces + 1] = "\\n"
		elseif ch == "\t" then
			pieces[#pieces + 1] = "\\t"
		elseif ch == "\r" then
			pieces[#pieces + 1] = "\\r"
		else
			pieces[#pieces + 1] = ch
		end
	end
	pieces[#pieces + 1] = "'"
	return table.concat(pieces)
end

local function asciiString(s: string): string
	local pieces = { "'" }
	for i = 1, #s do
		local ch = s:sub(i, i)
		local byte = string.byte(ch)
		if ch == "\\" then
			pieces[#pieces + 1] = "\\\\"
		elseif ch == "'" then
			pieces[#pieces + 1] = "\\'"
		elseif ch == "\n" then
			pieces[#pieces + 1] = "\\n"
		elseif ch == "\t" then
			pieces[#pieces + 1] = "\\t"
		elseif ch == "\r" then
			pieces[#pieces + 1] = "\\r"
		elseif byte < 32 or byte > 126 then
			pieces[#pieces + 1] = string.format("\\x%02x", byte)
		else
			pieces[#pieces + 1] = ch
		end
	end
	pieces[#pieces + 1] = "'"
	return table.concat(pieces)
end

objectRepr = function(obj: PyObject?): string
	if obj == nil then
		return "None"
	end

	local t = obj.__type

	if t == "str" then
		return reprString(obj.__value :: string)
	elseif t == "int" or t == "float" then
		return tostring(obj.__value)
	elseif t == "bool" then
		return pyBoolString(obj.__value)
	elseif t == "NoneType" then
		return pyNoneString()
	elseif t == "bytes" then
		local repr = tryRepr(obj)
		return repr or "b''"
	elseif t == "type" then
		local info = obj.__value
		local name = if type(info) == "table" and (info :: any).name then (info :: any).name else "object"
		return "<class '" .. tostring(name) .. "'>"
	elseif t == "list" then
		local repr = tryRepr(obj)
		if repr then
			return repr
		end
		local arr = obj.__value :: { PyObject }
		local pieces = table.create(#arr)
		for i, item in ipairs(arr) do
			pieces[i] = objectRepr(ensurePy(item))
		end
		return "[" .. table.concat(pieces, ", ") .. "]"
	elseif t == "tuple" then
		local repr = tryRepr(obj)
		if repr then
			return repr
		end
		local arr = obj.__value :: { PyObject }
		local pieces = table.create(#arr)
		for i, item in ipairs(arr) do
			pieces[i] = objectRepr(ensurePy(item))
		end
		if #arr == 1 then
			return "(" .. pieces[1] .. ",)"
		end
		return "(" .. table.concat(pieces, ", ") .. ")"
	elseif t == "dict" then
		local repr = tryRepr(obj)
		if repr then
			return repr
		end
		local entries = obj.__value :: { [string]: { key: PyObject, value: PyObject } }
		local parts: { string } = {}
		for _, entry in pairs(entries) do
			local keyStr = objectRepr(entry.key)
			local valueStr = objectRepr(entry.value)
			parts[#parts + 1] = keyStr .. ": " .. valueStr
		end
		if #parts == 0 then
			return "{}"
		end
		table.sort(parts)
		return "{" .. table.concat(parts, ", ") .. "}"
	elseif t == "set" then
		local repr = tryRepr(obj)
		if repr then
			return repr
		end
		local entries = obj.__value :: { [string]: { value: PyObject } }
		local parts: { string } = {}
		for _, entry in pairs(entries) do
			parts[#parts + 1] = objectRepr(entry.value)
		end
		if #parts == 0 then
			return "set()"
		end
		table.sort(parts)
		return "{" .. table.concat(parts, ", ") .. "}"
	else
		local repr = tryRepr(obj)
		return repr or ("<" .. t .. " object>")
	end
end

local function computeRangeLength(start: number, stop: number, step: number): number
	if step > 0 then
		if start >= stop then
			return 0
		end
		return math.max(0, math.floor((stop - start + step - 1) / step))
	elseif step < 0 then
		if start <= stop then
			return 0
		end
		local span = start - stop
		local positiveStep = -step
		return math.max(0, math.floor((span + positiveStep - 1) / positiveStep))
	else
		error("ValueError: range() arg 3 must not be zero", 3)
	end
end

local rangeTypeCached = nil

local function ensureRangeType()
	if rangeTypeCached then
		return rangeTypeCached
	end
	local ok, existing = pcall(function()
		return base.getTypeObject("range")
	end)
	local rangeType
	if ok then
		rangeType = existing
	else
		rangeType = base.registerType("range", {})
	end
	rangeType.methods = rangeType.methods or {}
	local rangeMethods = rangeType.methods :: { [string]: (PyObject, { PyObject }?) -> PyObject }
	if not rangeMethods["__len__"] then
		rangeMethods["__len__"] = function(selfObj: PyObject)
			local data = selfObj.__value
			local length = computeRangeLength(data.start, data.stop, data.step)
			return base.newInt(length)
		end
	end
	if not rangeMethods["__repr__"] then
		rangeMethods["__repr__"] = function(selfObj: PyObject)
			local data = selfObj.__value
			local pieces = { "range(" .. tostring(data.start), tostring(data.stop) }
			if data.step ~= 1 then
				pieces[#pieces + 1] = tostring(data.step)
			end
			return base.newPyObject("str", table.concat(pieces, ", ") .. ")")
		end
	end
	rangeTypeCached = rangeType
	return rangeType
end

local function collectIterable(obj: PyObject, caller: string): { PyObject }
	local t = obj.__type
	if t == "list" or t == "tuple" then
		return obj.__value
	elseif t == "set" then
		local values = {}
		for _, entry in pairs(obj.__value) do
			values[#values + 1] = entry.value
		end
		return values
	elseif t == "dict" then
		local keys = {}
		for _, entry in pairs(obj.__value) do
			keys[#keys + 1] = entry.key
		end
		return keys
	elseif t == "str" then
		local chars = {}
		local s: string = obj.__value
		for i = 1, #s do
			chars[#chars + 1] = base.newPyObject("str", s:sub(i, i))
		end
		return chars
	elseif t == "bytes" then
		local arr = {}
		local s: string = obj.__value
		for i = 1, #s do
			arr[#arr + 1] = base.newPyObject("int", string.byte(s, i))
		end
		return arr
	elseif t == "range" then
		local values = {}
		local data = obj.__value
		local current = data.start
		if data.step > 0 then
			while current < data.stop do
				values[#values + 1] = base.newInt(current)
				current += data.step
			end
		else
			while current > data.stop do
				values[#values + 1] = base.newInt(current)
				current += data.step
			end
		end
		return values
	else
		error("TypeError: '" .. caller .. "' argument must be iterable", 3)
	end
end

local function wrapBuiltin(name: string, handler: (args: { PyObject }) -> PyObject)
	local builtinType = base.getTypeObject("builtin_function_or_method")
	local builtin: PyObject = {
		__type = "builtin_function_or_method",
		__value = {
			self = nil,
			name = name,
			func = function(_self: PyObject?, args: { PyObject }?)
				local coerced: { PyObject } = {}
				if args then
					for i, arg in ipairs(args) do
						coerced[i] = ensurePy(arg)
					end
				end
				return handler(coerced)
			end,
		},
		__dict = {},
		__typeobj = builtinType,
	}
	return builtin
end

-- print(*args, sep=' ', end='\n') -- sep/end not yet supported (defaults only)
function Functions.print_(args: { PyObject }): PyObject
	local pieces = {}
	for i, arg in ipairs(args) do
		pieces[i] = pyToString(arg)
	end
	Functions._writer(table.concat(pieces, " "))
	return obj_builtins.None()
end

-- len(obj)
function Functions.len(obj: PyObject): PyObject
	if obj == nil then
		error("TypeError: len() takes exactly one argument (0 given)", 2)
	end
	local ok, lenMethod = pcall(function()
		return base.getattr(obj, "__len__")
	end)
	if ok and lenMethod then
		return base.call(lenMethod, {})
	end
	local t = obj.__type
	if t == "str" then
		return base.newInt(#(obj.__value :: string))
	elseif t == "bytes" then
		return base.newInt(#(obj.__value :: string))
	end
	error("TypeError: object of type '" .. t .. "' has no len()", 2)
end

-- type(obj)
function Functions.type_(obj: PyObject): PyObject
	if obj == nil then
		error("TypeError: type() takes 1 argument", 2)
	end
	return base.newPyObject("type", { name = obj.__type })
end

-- range(start, stop?, step?)
function Functions.rangeVararg(args: { PyObject }): PyObject
	local count = #args
	if count == 0 or count > 3 then
		error("TypeError: range expected 1 to 3 arguments", 2)
	end
	local startObj: PyObject
	local stopObj: PyObject
	local stepObj: PyObject
	if count == 1 then
		startObj = base.newInt(0)
		stopObj = args[1]
		stepObj = base.newInt(1)
	elseif count == 2 then
		startObj = args[1]
		stopObj = args[2]
		stepObj = base.newInt(1)
	else
		startObj = args[1]
		stopObj = args[2]
		stepObj = args[3]
	end
	local startNum = truncateTowardsZero(pyToNumber(startObj, "start", false))
	local stopNum = truncateTowardsZero(pyToNumber(stopObj, "stop", false))
	local stepNum = truncateTowardsZero(pyToNumber(stepObj, "step", false))
	if stepNum == 0 then
		error("ValueError: range() arg 3 must not be zero", 2)
	end
	ensureRangeType()
	return base.newPyObject("range", {
		start = startNum,
		stop = stopNum,
		step = stepNum,
	})
end

-- int(x)
function Functions.int_(value: PyObject?): PyObject
	if value == nil then
		return base.newInt(0)
	end
	local t = value.__type
	if t == "int" then
		return value
	elseif t == "float" then
		return base.newInt(truncateTowardsZero(value.__value))
	elseif t == "bool" then
		return base.newInt(value.__value and 1 or 0)
	elseif t == "str" then
		local parsed = tonumber(value.__value)
		if not parsed then
			error("ValueError: invalid literal for int() with base 10", 2)
		end
		return base.newInt(truncateTowardsZero(parsed))
	elseif t == "NoneType" then
		return base.newInt(0)
	end
	error("TypeError: int() argument must be a string, a bytes-like object or a real number", 2)
end

-- float(x)
function Functions.float_(value: PyObject?): PyObject
	if value == nil then
		return base.newFloat(0)
	end
	local t = value.__type
	if t == "float" then
		return value
	elseif t == "int" then
		return base.newFloat(value.__value)
	elseif t == "bool" then
		return base.newFloat(value.__value and 1 or 0)
	elseif t == "str" then
		local parsed = tonumber(value.__value)
		if not parsed then
			error("ValueError: could not convert string to float", 2)
		end
		return base.newFloat(parsed)
	elseif t == "NoneType" then
		return base.newFloat(0)
	end
	error("TypeError: float() argument must be a string or a real number", 2)
end

-- str(x)
function Functions.str_(value: PyObject?): PyObject
	if value == nil then
		return base.newPyObject("str", "")
	end
	return base.newPyObject("str", pyToString(value))
end

-- bool(x)
function Functions.bool_(value: PyObject?): PyObject
	if value == nil then
		return obj_builtins.False()
	end
	return if base.truthy(value) then obj_builtins.True() else obj_builtins.False()
end

function Functions.repr_(value: PyObject?): PyObject
	return base.newPyObject("str", objectRepr(value))
end

function Functions.ascii_(value: PyObject?): PyObject
	if value == nil then
		return base.newPyObject("str", "None")
	end
	local t = value.__type
	if t == "str" then
		return base.newPyObject("str", asciiString(value.__value))
	end
	return Functions.repr_(value)
end

local subclassMap: { [string]: { [string]: boolean } } = {
	bool = { int = true },
}

function Functions.isinstance_(args: { PyObject }): PyObject
	if #args ~= 2 then
		error("TypeError: isinstance() takes exactly 2 arguments", 2)
	end
	local instance = ensurePy(args[1])
	local typeSpec = ensurePy(args[2])
	local targets: { string } = {}
	collectTypeNames(typeSpec, targets)
	if #targets == 0 then
		return base.newBool(false)
	end
	local instanceType = instance.__type
	local subtype = subclassMap[instanceType]
	for _, expected in ipairs(targets) do
		if instanceType == expected then
			return base.newBool(true)
		end
		if subtype and subtype[expected] then
			return base.newBool(true)
		end
	end
	return base.newBool(false)
end

local function coerceFormatArg(obj: PyObject): (any, string)
	local t = obj.__type
	if t == "int" or t == "float" then
		return obj.__value, t
	elseif t == "bool" then
		return (obj.__value and 1 or 0), "int"
	elseif t == "str" then
		return obj.__value, "str"
	end
	return obj, t
end

function Functions.format_(value: PyObject?, spec: PyObject?): PyObject
	if value == nil then
		error("TypeError: format() missing 1 required positional argument", 2)
	end
	local specStr = ""
	if spec ~= nil then
		if spec.__type ~= "str" then
			error("TypeError: format() specifier must be a string", 2)
		end
		specStr = spec.__value
	end
	if specStr == "" then
		return Functions.str_(value)
	end
	local rawValue, valueType = coerceFormatArg(value)
	local fmt = "%" .. specStr
	local ok, result = pcall(string.format, fmt, rawValue)
	if not ok then
		if valueType == "str" and specStr == "s" then
			return base.newPyObject("str", tostring(rawValue))
		end
		error("ValueError: invalid format specifier '" .. specStr .. "' for type '" .. valueType .. "'", 2)
	end
	return base.newPyObject("str", result)
end

local function addPyObjects(a: PyObject, b: PyObject): PyObject
	return base.operate("add", a, b)
end

local function toComparableValue(obj: PyObject): (number | string, string)
	local t = obj.__type
	if t == "int" or t == "float" then
		return obj.__value, "number"
	elseif t == "bool" then
		return obj.__value and 1 or 0, "number"
	elseif t == "str" then
		return obj.__value, "string"
	else
		error("TypeError: unsupported operand type for comparison: '" .. t .. "'", 3)
	end
end

local function compareLess(a: PyObject, b: PyObject): boolean
	local va, kindA = toComparableValue(a)
	local vb, kindB = toComparableValue(b)
	if kindA ~= kindB then
		error("TypeError: '<' not supported between instances of '" .. a.__type .. "' and '" .. b.__type .. "'", 3)
	end
	return va < vb
end

local function compareGreater(a: PyObject, b: PyObject): boolean
	local va, kindA = toComparableValue(a)
	local vb, kindB = toComparableValue(b)
	if kindA ~= kindB then
		error("TypeError: '>' not supported between instances of '" .. a.__type .. "' and '" .. b.__type .. "'", 3)
	end
	return va > vb
end

-- sum(iterable, start=0)
function Functions.sum_(args: { PyObject }): PyObject
	local count = #args
	if count == 0 then
		error("TypeError: sum() takes at least 1 argument", 2)
	end
	local iterable = args[1]
	local startValue = if count >= 2 then args[2] else base.newInt(0)
	if count > 2 then
		error("TypeError: sum() takes at most 2 arguments", 2)
	end
	local total = ensurePy(startValue)
	local values = collectIterable(iterable, "sum")
	for _, item in ipairs(values) do
		total = addPyObjects(total, ensurePy(item))
	end
	return total
end

local function findExtreme(args: { PyObject }, mode: string): PyObject
	local compare: (PyObject, PyObject) -> boolean
	if mode == "min" then
		compare = compareLess
	else
		compare = compareGreater
	end
	local best = args[1]
	for i = 2, #args do
		if compare(ensurePy(args[i]), ensurePy(best)) then
			best = args[i]
		end
	end
	return ensurePy(best)
end

-- min(*args) or min(iterable)
function Functions.min_(args: { PyObject }): PyObject
	local count = #args
	if count == 0 then
		error("TypeError: min() expected at least one argument", 2)
	elseif count == 1 then
		local values = collectIterable(args[1], "min")
		if #values == 0 then
			error("ValueError: min() arg is an empty sequence", 2)
		end
		return findExtreme(values, "min")
	else
		return findExtreme(args, "min")
	end
end

-- max(*args) or max(iterable)
function Functions.max_(args: { PyObject }): PyObject
	local count = #args
	if count == 0 then
		error("TypeError: max() expected at least one argument", 2)
	elseif count == 1 then
		local values = collectIterable(args[1], "max")
		if #values == 0 then
			error("ValueError: max() arg is an empty sequence", 2)
		end
		return findExtreme(values, "max")
	else
		return findExtreme(args, "max")
	end
end

-- bytes(x) -> bytes
function Functions.bytes(val: PyObject?): PyObject
	if val == nil then
		return obj_builtins.Bytes("")
	end
	if val.__type == "str" then
		return obj_builtins.Bytes(val.__value)
	elseif val.__type == "list" then
		local arr = {}
		for i, v in ipairs(val.__value) do
			if v.__type ~= "int" then
				error("TypeError: bytes() list must contain ints", 2)
			end
			arr[i] = v.__value
		end
		return obj_builtins.Bytes(arr)
	else
		error("TypeError: bytes() argument must be str or list of ints", 2)
	end
end

function Functions.createBuiltins(): { [string]: PyObject }
	local builtinsTable = {
		["print"] = wrapBuiltin("print", function(args)
			return Functions.print_(args)
		end),
		["len"] = wrapBuiltin("len", function(args)
			if #args ~= 1 then
				error("TypeError: len() takes exactly one argument", 2)
			end
			return Functions.len(args[1])
		end),
		["type"] = wrapBuiltin("type", function(args)
			if #args ~= 1 then
				error("TypeError: type() takes exactly one argument", 2)
			end
			return Functions.type_(args[1])
		end),
		["range"] = wrapBuiltin("range", function(args)
			return Functions.rangeVararg(args)
		end),
		["int"] = wrapBuiltin("int", function(args)
			return Functions.int_(args[1])
		end),
		["float"] = wrapBuiltin("float", function(args)
			return Functions.float_(args[1])
		end),
		["str"] = wrapBuiltin("str", function(args)
			return Functions.str_(args[1])
		end),
		["bool"] = wrapBuiltin("bool", function(args)
			return Functions.bool_(args[1])
		end),
		["repr"] = wrapBuiltin("repr", function(args)
			if #args ~= 1 then
				error("TypeError: repr() takes exactly one argument", 2)
			end
			return Functions.repr_(args[1])
		end),
		["ascii"] = wrapBuiltin("ascii", function(args)
			if #args ~= 1 then
				error("TypeError: ascii() takes exactly one argument", 2)
			end
			return Functions.ascii_(args[1])
		end),
		["format"] = wrapBuiltin("format", function(args)
			if #args == 0 or #args > 2 then
				error("TypeError: format() takes at least 1 argument (value[, format_spec])", 2)
			end
			return Functions.format_(args[1], args[2])
		end),
		["sum"] = wrapBuiltin("sum", function(args)
			return Functions.sum_(args)
		end),
		["min"] = wrapBuiltin("min", function(args)
			return Functions.min_(args)
		end),
		["max"] = wrapBuiltin("max", function(args)
			return Functions.max_(args)
		end),
		["bytes"] = wrapBuiltin("bytes", function(args)
			return Functions.bytes(args[1])
		end),
		["isinstance"] = wrapBuiltin("isinstance", function(args)
			return Functions.isinstance_(args)
		end),
	}

	local exceptionTypes = exceptions.createBuiltins()
	for name, obj in pairs(exceptionTypes) do
		builtinsTable[name] = obj
	end

	builtinsTable["_pylua_match_exception"] = wrapBuiltin("_pylua_match_exception", function(args)
		if #args ~= 2 then
			error("TypeError: _pylua_match_exception expects 2 arguments", 2)
		end
		return exceptions.matchException(args[1], args[2])
	end)

	builtinsTable["_pylua_raise"] = wrapBuiltin("_pylua_raise", function(args)
		if #args ~= 1 then
			error("TypeError: _pylua_raise expects an exception instance", 2)
		end
		exceptions.reraise(args[1])
		return obj_builtins.None()
	end)

	return builtinsTable
end

return Functions
