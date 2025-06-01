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

-- Built-in range function
function builtins.range(...)
	local args = {...}
	local start, stop, step
	
	-- Convert string arguments to numbers
	for i = 1, #args do
		if type(args[i]) == "string" then
			local num = tonumber(args[i])
			if num then
				args[i] = num
			else
				error("range() argument must be a number, got '" .. args[i] .. "'")
			end
		elseif type(args[i]) ~= "number" then
			error("range() argument must be a number, got " .. type(args[i]))
		end
	end
	
	if #args == 1 then
		start, stop, step = 0, args[1], 1
	elseif #args == 2 then
		start, stop, step = args[1], args[2], 1
	elseif #args == 3 then
		start, stop, step = args[1], args[2], args[3]
	else
		error("range expected 1 to 3 arguments, got " .. #args)
	end
	
	local result = {}
	if step > 0 then
		for i = start, stop - 1, step do
			table.insert(result, i)
		end
	elseif step < 0 then
		for i = start, stop + 1, step do
			table.insert(result, i)
		end
	else
		error("range() arg 3 must not be zero")
	end
	
	return result
end

-- Built-in min function
function builtins.min(...)
	local args = {...}
	if #args == 0 then
		error("min expected at least 1 argument, got 0")
	end
	
	-- Handle single iterable argument
	if #args == 1 and type(args[1]) == "table" then
		args = args[1]
		if #args == 0 then
			error("min() arg is an empty sequence")
		end
	end
	
	local minimum = args[1]
	for i = 2, #args do
		if args[i] < minimum then
			minimum = args[i]
		end
	end
	return minimum
end

-- Built-in max function
function builtins.max(...)
	local args = {...}
	if #args == 0 then
		error("max expected at least 1 argument, got 0")
	end
	
	-- Handle single iterable argument
	if #args == 1 and type(args[1]) == "table" then
		args = args[1]
		if #args == 0 then
			error("max() arg is an empty sequence")
		end
	end
	
	local maximum = args[1]
	for i = 2, #args do
		if args[i] > maximum then
			maximum = args[i]
		end
	end
	return maximum
end

-- Built-in sum function
function builtins.sum(iterable, start)
	start = start or 0
	if type(iterable) ~= "table" then
		error("sum() first argument must be iterable")
	end
	
	local total = start
	for _, value in ipairs(iterable) do
		if type(value) == "number" then
			total = total + value
		else
			error("unsupported operand type(s) for +: '" .. type(total) .. "' and '" .. type(value) .. "'")
		end
	end
	return total
end

-- Built-in abs function
function builtins.abs(x)
	if type(x) ~= "number" then
		error("bad argument to abs (number expected, got " .. type(x) .. ")")
	end
	return math.abs(x)
end

-- Built-in round function
function builtins.round(number, ndigits)
	if type(number) ~= "number" then
		error("must be real number, not " .. type(number))
	end
	
	ndigits = ndigits or 0
	if type(ndigits) ~= "number" then
		error("'int' object cannot be interpreted as an integer")
	end
	
	local mult = 10^ndigits
	return math.floor(number * mult + 0.5) / mult
end

-- Built-in bool function
function builtins.bool(x)
	if x == nil or x == false then
		return false
	elseif x == 0 or x == "" then
		return false
	elseif type(x) == "table" and #x == 0 then
		return false
	else
		return true
	end
end

-- Built-in float function
function builtins.float(x)
	if type(x) == "number" then
		return x
	elseif type(x) == "string" then
		local num = tonumber(x)
		if num then
			return num
		else
			error("could not convert string to float: '" .. x .. "'")
		end
	elseif type(x) == "boolean" then
		return x and 1.0 or 0.0
	else
		error("float() argument must be a string or a number, not '" .. type(x) .. "'")
	end
end

-- Built-in pow function
function builtins.pow(base, exp, mod)
	if type(base) ~= "number" or type(exp) ~= "number" then
		error("pow() arguments must be numbers")
	end
	
	local result = base ^ exp
	
	if mod then
		if type(mod) ~= "number" then
			error("pow() mod argument must be a number")
		end
		result = result % mod
	end
		return result
end

-- Built-in enumerate function
function builtins.enumerate(iterable, start)
	start = start or 0
	
	local result = {}
	
	-- Handle strings
	if type(iterable) == "string" then
		for i = 1, #iterable do
			table.insert(result, {start + i - 1, iterable:sub(i, i)})
		end
	-- Handle tables (lists)
	elseif type(iterable) == "table" then
		for i, value in ipairs(iterable) do
			table.insert(result, {start + i - 1, value})
		end
	else
		error("enumerate() argument must be iterable (string or list)")
	end
	
	return result
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
