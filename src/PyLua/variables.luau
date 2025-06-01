-- PyLua Variables
-- Manages variable storage and retrieval

local Variables = {}

-- Variable storage
local variables = {}

-- Set a variable value
function Variables.set(name, value)
	variables[name] = value
end

-- Get a variable value
function Variables.get(name)
	return variables[name]
end

-- Check if a variable exists
function Variables.exists(name)
	return variables[name] ~= nil
end

-- Get all variables (for debugging)
function Variables.getAll()
	return variables
end

-- Clear all variables
function Variables.clear()
	variables = {}
end

return Variables
