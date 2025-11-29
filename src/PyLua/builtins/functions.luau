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
	-- Pre-allocate with generous size estimate (2x for escapes + quotes)
	local pieces = table.create(#s * 2 + 2)
	pieces[1] = "'"
	local idx = 2
	for i = 1, #s do
		local ch = s:sub(i, i)
		if ch == "\\" then
			pieces[idx] = "\\\\"
		elseif ch == "'" then
			pieces[idx] = "\\'"
		elseif ch == "\n" then
			pieces[idx] = "\\n"
		elseif ch == "\t" then
			pieces[idx] = "\\t"
		elseif ch == "\r" then
			pieces[idx] = "\\r"
		else
			pieces[idx] = ch
		end
		idx += 1
	end
	pieces[idx] = "'"
	return table.concat(pieces, "", 1, idx)
end

local function asciiString(s: string): string
	-- Pre-allocate with generous size estimate (4x for hex escapes + quotes)
	local pieces = table.create(#s * 4 + 2)
	pieces[1] = "'"
	local idx = 2
	for i = 1, #s do
		local ch = s:sub(i, i)
		local byte = string.byte(ch)
		if ch == "\\" then
			pieces[idx] = "\\\\"
		elseif ch == "'" then
			pieces[idx] = "\\'"
		elseif ch == "\n" then
			pieces[idx] = "\\n"
		elseif ch == "\t" then
			pieces[idx] = "\\t"
		elseif ch == "\r" then
			pieces[idx] = "\\r"
		elseif byte < 32 or byte > 126 then
			pieces[idx] = string.format("\\x%02x", byte)
		else
			pieces[idx] = ch
		end
		idx += 1
	end
	pieces[idx] = "'"
	return table.concat(pieces, "", 1, idx)
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
local superTypeCached: base.PyType? = nil

local function ensureSuperType(): base.PyType
	if superTypeCached then
		return superTypeCached
	end
	local objectType = base.getTypeObject("object")
	superTypeCached = base.registerType("super", {
		bases = { objectType },
	})
	return superTypeCached :: base.PyType
end

local function unwrapSentinel(value: any): any
	if type(value) == "table" and value.__nil then
		return nil
	end
	return value
end

local function resolveTypeFromClass(obj: PyObject): base.PyType
	if obj.__type ~= "type" then
		error("TypeError: super() argument 1 must be a type", 2)
	end
	local info = obj.__value
	if type(info) == "table" and (info :: any).pyType then
		return (info :: any).pyType
	end
	local name = if type(info) == "table" and (info :: any).name then (info :: any).name else obj.__type
	return base.getTypeObject(name)
end

local function resolveInstance(value: any): PyObject
	local unwrapped = unwrapSentinel(value)
	if not unwrapped then
		error("TypeError: super() argument 2 cannot be None", 2)
	end
	return base.ensurePyObject(unwrapped)
end

local function computeStartIndex(mro: { base.PyType }, owner: base.PyType): number
	for idx, pyType in ipairs(mro) do
		if pyType == owner then
			return idx + 1
		end
	end
	error("RuntimeError: super(): current class not found in MRO", 2)
end

local function buildSuperObject(owner: base.PyType, instance: PyObject): PyObject
	local instanceType = instance.__typeobj
	local mro = base.computeMro(instanceType)
	local startIndex = computeStartIndex(mro, owner)
	local superType = ensureSuperType()
	local superObj: PyObject = {
		__type = "super",
		__value = {
			instance = instance,
			mro = mro,
			index = startIndex,
		},
		__dict = {},
		__typeobj = superType,
	}
	return superObj
end

local function resolveCurrentClassAndInstance(): (base.PyType, PyObject)
	local frame = base.getActiveFrame()
	if not frame then
		error("RuntimeError: super(): no active frame", 2)
	end
	local funcObj = (frame :: any).function_object
	if not funcObj or funcObj.__type ~= "function" then
		error("RuntimeError: super(): unable to determine current function", 2)
	end
	local funcInfo = funcObj.__value
	if type(funcInfo) ~= "table" then
		error("RuntimeError: super(): invalid function metadata", 2)
	end
	local owner = (funcInfo :: any).owner
	if not owner then
		error("RuntimeError: super(): current function is not bound to a class", 2)
	end
	local code = (funcInfo :: any).code
	local varnames = if code and code.varnames then code.varnames else {}
	local firstVar = if #varnames > 0 then varnames[1] else nil
	if not firstVar then
		error("RuntimeError: super(): cannot determine implicit self", 2)
	end
	local localsTable = frame.locals
	local rawSelf = localsTable[firstVar]
	local instance = resolveInstance(rawSelf)
	return owner, instance
end

local function superGetattr(selfObj: PyObject, name: string): PyObject?
	local payload = selfObj.__value
	if type(payload) ~= "table" then
		error("TypeError: invalid super object", 2)
	end
	local instance = (payload :: any).instance
	local mro = (payload :: any).mro
	local startIndex = (payload :: any).index
	if not instance or not mro or not startIndex then
		error("TypeError: malformed super object", 2)
	end
	for i = startIndex, #mro do
		local baseType = mro[i]
		local value, kind, owner = base.lookupAttributeOnType(baseType, name)
		if value ~= nil then
			if kind == "builtin" then
				return base.bindBuiltinMethod(
					instance,
					name,
					value :: (PyObject, { PyObject }?) -> PyObject,
					owner or baseType
				)
			else
				local attrObj = value :: PyObject
				if attrObj.__type == "function" then
					return base.bindPythonMethod(instance, attrObj, owner or baseType)
				end
				return attrObj
			end
		end
	end
	error("AttributeError: 'super' object has no attribute '" .. name .. "'", 2)
end

(function()
	local ok, superType = pcall(function()
		return ensureSuperType()
	end)
	if ok and superType then
		superType.__getattr = superGetattr
	elseif ok then
		-- already registered: update __getattr
		superTypeCached = superType
		superTypeCached.__getattr = superGetattr
	end
end)()

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
			local result: string
			if data.step == 1 then
				result = string.format("range(%s, %s)", tostring(data.start), tostring(data.stop))
			else
				result =
					string.format("range(%s, %s, %s)", tostring(data.start), tostring(data.stop), tostring(data.step))
			end
			return base.newPyObject("str", result)
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
	return base.newPyObject("type", { name = obj.__type, pyType = obj.__typeobj })
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

local function resolvePyTypeFromSpec(spec: PyObject): base.PyType
	if spec.__type == "type" then
		local info = spec.__value
		if type(info) == "table" and (info :: any).pyType then
			return (info :: any).pyType
		end
		local name = if type(info) == "table" and (info :: any).name then (info :: any).name else spec.__type
		return base.getTypeObject(name)
	elseif spec.__type == "builtin_function_or_method" then
		local inner = spec.__value
		local name = if type(inner) == "table" then (inner :: any).name else nil
		if not name then
			error("TypeError: isinstance() arg 2 has invalid type object", 3)
		end
		return base.getTypeObject(name)
	else
		error("TypeError: isinstance() arg 2 must be a type or tuple of types", 3)
	end
end

local function collectPyTypes(spec: PyObject, out: { base.PyType })
	if spec.__type == "tuple" then
		local elements = spec.__value :: { PyObject }
		for _, item in ipairs(elements) do
			collectPyTypes(item, out)
		end
	else
		out[#out + 1] = resolvePyTypeFromSpec(spec)
	end
end

local function isSubtypeOf(candidate: base.PyType, target: base.PyType): boolean
	if candidate == target then
		return true
	end
	local bases = candidate.bases
	if not bases then
		return false
	end
	for _, baseType in ipairs(bases) do
		if isSubtypeOf(baseType, target) then
			return true
		end
	end
	return false
end

function Functions.isinstance_(args: { PyObject }): PyObject
	if #args ~= 2 then
		error("TypeError: isinstance() takes exactly 2 arguments", 2)
	end
	local instance = ensurePy(args[1])
	local typeSpec = ensurePy(args[2])
	local targets: { base.PyType } = {}
	collectPyTypes(typeSpec, targets)
	if #targets == 0 then
		return base.newBool(false)
	end
	local instanceType = instance.__typeobj
	for _, target in ipairs(targets) do
		if isSubtypeOf(instanceType, target) then
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

function Functions.next_(args: { PyObject }): PyObject
	local count = #args
	if count == 0 then
		error("TypeError: next() expected at least 1 argument, got 0", 2)
	elseif count > 2 then
		error("TypeError: next() expected at most 2 arguments, got " .. tostring(count), 2)
	end

	local iterator = ensurePy(args[1])
	local ok, nextMethod = pcall(function()
		return base.getattr(iterator, "__next__")
	end)
	if not ok or not nextMethod then
		error("TypeError: '" .. iterator.__type .. "' object is not an iterator", 2)
	end

	local success, result = pcall(function()
		return base.call(nextMethod, {})
	end)

	if success then
		return result
	end

	local err = result
	if type(err) == "table" and (err :: any).__type == "StopIteration" then
		if count == 2 then
			return ensurePy(args[2])
		end
		error(err, 0)
	end

	error(err, 0)
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

function Functions.super_(args: { PyObject }): PyObject
	local count = #args
	local owner: base.PyType
	local instance: PyObject
	if count == 0 then
		owner, instance = resolveCurrentClassAndInstance()
	elseif count == 2 then
		owner = resolveTypeFromClass(args[1])
		instance = resolveInstance(args[2])
	else
		error("TypeError: super() expects 0 or 2 arguments", 2)
	end
	return buildSuperObject(owner, instance)
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
		["next"] = wrapBuiltin("next", function(args)
			return Functions.next_(args)
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
		["super"] = wrapBuiltin("super", function(args)
			return Functions.super_(args)
		end),
	}

	local exceptionTypes = exceptions.createBuiltins()
	for name, obj in pairs(exceptionTypes) do
		builtinsTable[name] = obj
	end

	builtinsTable["object"] = base.wrapType(base.getTypeObject("object"))

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
