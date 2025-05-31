-- PyLua Built-in Functions
-- Contains all the built-in Python functions

local Builtins = {}

-- Built-in functions that will be available in the Python environment
local builtins = {}

-- Built-in print function
function builtins.print(...)
	local args = {...}
	local output = {}
	
	for i, arg in ipairs(args) do
		table.insert(output, tostring(arg))
	end
	
	print(table.concat(output, " "))
end

-- Built-in len function
function builtins.len(obj)
	if type(obj) == "string" then
		return #obj
	elseif type(obj) == "table" then
		return #obj
	else
		return 0
	end
end

-- Built-in str function
function builtins.str(obj)
	return tostring(obj)
end

-- Built-in int function
function builtins.int(obj)
	local num = tonumber(obj)
	if num then
		return math.floor(num)
	else
		error("Cannot convert to int: " .. tostring(obj))
	end
end

-- Built-in type function
function builtins.type(obj)
	local luaType = type(obj)
	if luaType == "number" then
		if obj % 1 == 0 then
			return "int"
		else
			return "float"
		end
	elseif luaType == "string" then
		return "str"
	elseif luaType == "boolean" then
		return "bool"
	elseif luaType == "table" then
		return "list"
	else
		return luaType
	end
end

-- Get all built-in functions
function Builtins.getAll()
	return builtins
end

-- Add a new built-in function
function Builtins.add(name, func)
	builtins[name] = func
end

-- Check if a function is a built-in
function Builtins.exists(name)
	return builtins[name] ~= nil
end

return Builtins
