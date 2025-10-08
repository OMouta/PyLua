local Exceptions = {}

local base = require("../objects/base")
local builtins = require("../objects/builtins")

type PyObject = base.PyObject

local DEFAULT_EXCEPTIONS = {
	"Exception",
	"TypeError",
	"ValueError",
	"ZeroDivisionError",
	"NameError",
	"UnboundLocalError",
	"IndexError",
	"AttributeError",
	"RuntimeError",
}

local typeCache: { [string]: any } = {}

local function ensureExceptionType(name: string)
	if typeCache[name] then
		return typeCache[name]
	end
	local ok, existing = pcall(function()
		if typeof(base.getTypeObject) == "function" then
			return base.getTypeObject(name)
		end
		return nil
	end)
	local typeObj
	if ok then
		typeObj = existing
	else
		typeObj = base.registerType(name, {})
	end
	typeObj.methods = typeObj.methods or {}

	local function render(selfObj: PyObject)
		local payload = selfObj.__value
		local message = if type(payload) == "table" then (payload :: any).message else nil
		if message and message ~= "" then
			return base.newPyObject("str", name .. ": " .. tostring(message))
		end
		return base.newPyObject("str", name)
	end

	if not typeObj.methods["__str__"] then
		typeObj.methods["__str__"] = render
	end
	if not typeObj.methods["__repr__"] then
		typeObj.methods["__repr__"] = function(selfObj: PyObject)
			local payload = selfObj.__value
			local message = if type(payload) == "table" then (payload :: any).message else nil
			if message and message ~= "" then
				return base.newPyObject("str", name .. "('" .. tostring(message) .. "')")
			end
			return base.newPyObject("str", name .. "()")
		end
	end

	typeCache[name] = typeObj
	return typeObj
end

local function normalizeMessage(err: string): string
	local cleaned = err
	cleaned = string.gsub(cleaned, "^%s+", "")
	-- Strip script/line prefixes (e.g., Script: message)
	local colonPos = string.find(cleaned, ": ")
	if colonPos and colonPos < 40 then
		local prefix = string.sub(cleaned, 1, colonPos - 1)
		if not string.find(prefix, "%s") then
			cleaned = string.sub(cleaned, colonPos + 2)
		end
	end
	return cleaned
end

local function splitError(text: string): (string, string?)
	local trimmed = normalizeMessage(text)
	local name, message = string.match(trimmed, "^([%a_][%w_]*%f[:]):%s*(.*)$")
	if name then
		name = string.gsub(name, ":$", "")
		return name, message
	end

	local genericName, rest = string.match(trimmed, "^([%a_][%w_]+Error)%s*(.*)$")
	if genericName then
		return genericName, rest
	end

	local tailName, tailMsg = string.match(trimmed, "([%a_][%w_]+Error):%s*(.*)$")
	if tailName then
		return tailName, tailMsg
	end

	return "Exception", trimmed
end

local function createExceptionInstance(name: string, message: string?): PyObject
	ensureExceptionType(name)
	local payload = { message = message }
	local instance = base.newPyObject(name, payload)
	if message and message ~= "" then
		instance.__dict = instance.__dict or {}
		(instance.__dict :: any).message = base.newPyObject("str", message)
	end
	return instance
end

function Exceptions.fromLuauError(err: any): PyObject
	if type(err) == "table" and (err :: any).__type then
		return err :: any
	end
	local message: string? = nil
	local name = "Exception"
	if type(err) == "table" and (err :: any).message then
		message = tostring((err :: any).message)
	elseif type(err) == "string" then
		local parsedName, parsedMessage = splitError(err)
		name = parsedName
		message = parsedMessage
	else
		message = tostring(err)
	end
	return createExceptionInstance(name, message)
end

local function exceptionMessage(exc: PyObject): string
	local payload = exc.__value
	local msg = if type(payload) == "table" then (payload :: any).message else nil
	if msg and msg ~= "" then
		return exc.__type .. ": " .. tostring(msg)
	end
	return exc.__type
end

function Exceptions.toLuauMessage(exc: PyObject): string
	return exceptionMessage(exc)
end

function Exceptions.matchException(exc: PyObject, typeObj: PyObject?): PyObject
	if typeObj == nil then
		return builtins.False()
	end
	if typeObj.__type ~= "type" then
		error("TypeError: except clause must reference an exception type", 2)
	end
	local expected = if type(typeObj.__value) == "table" then (typeObj.__value :: any).name else nil
	if expected == nil then
		error("TypeError: malformed exception type", 2)
	end
	local matches = exc.__type == expected
	return if matches then builtins.True() else builtins.False()
end

function Exceptions.reraise(exc: PyObject)
	local message = exceptionMessage(exc)
	error(message, 2)
end

local function createTypeObject(name: string): PyObject
	return base.newPyObject("type", { name = name })
end

function Exceptions.createBuiltins(): { [string]: PyObject }
	local out: { [string]: PyObject } = {}
	for _, name in ipairs(DEFAULT_EXCEPTIONS) do
		out[name] = createTypeObject(name)
	end
	return out
end

return Exceptions
