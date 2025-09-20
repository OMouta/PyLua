--!strict
-- PyLua Built-in Functions
-- Phase 5 - Python built-in function implementations

local Functions = {}

local base = require("../objects/base")
type PyObject = base.PyObject

-- TODO: Implement Python built-in functions in Phase 5:

-- print(*args, sep=' ', end='\n')
function Functions.print_(args: { PyObject }): PyObject
	-- TODO: Implement print function
	error("print() not implemented yet - Phase 5", 2)
end

-- len(obj)
function Functions.len(obj: PyObject): PyObject
	-- TODO: Implement len function
	error("len() not implemented yet - Phase 5", 2)
end

-- type(obj)
function Functions.type_(obj: PyObject): PyObject
	-- TODO: Implement type function
	error("type() not implemented yet - Phase 5", 2)
end

-- range(start, stop, step)
function Functions.range(start: PyObject, stop: PyObject?, step: PyObject?): PyObject
	-- TODO: Implement range function
	error("range() not implemented yet - Phase 5", 2)
end

-- TODO: Implement other built-ins:
-- int(), float(), str(), bool()
-- sum(), min(), max()
-- abs(), round()

-- bytes(x) -> bytes
local obj_builtins = require("../objects/builtins")

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

return Functions
