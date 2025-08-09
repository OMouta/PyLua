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

return Functions
