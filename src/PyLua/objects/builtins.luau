--!strict
-- PyLua Built-in Types
-- Phase 3 - Python built-in type implementations

local Builtins = {}

local base = require('./base')
type PyObject = base.PyObject

-- TODO: Implement Python built-in types in Phase 3:
-- - int: Python integers
-- - float: Python floating point numbers  
-- - str: Python strings with methods
-- - bool: Python booleans (True/False)
-- - NoneType: Python None value
-- - type: Python type objects

-- Python None singleton
export type PyNone = PyObject & {
    __type: "NoneType",
    __value: nil,
}

-- Create Python None
function Builtins.none(): PyNone
    return base.newPyObject("NoneType", nil) :: PyNone
end

-- TODO: Implement other built-in types

return Builtins
