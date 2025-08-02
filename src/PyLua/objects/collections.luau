--!strict
-- PyLua Collection Types
-- Phase 3 - Python collection implementations

local Collections = {}

local base = require('./base')
type PyObject = base.PyObject

-- TODO: Implement Python collections in Phase 3:

-- Python list type
export type PyList = PyObject & {
    __type: "list",
    __value: {PyObject},
}

-- Python dict type  
export type PyDict = PyObject & {
    __type: "dict",
    __value: {[PyObject]: PyObject},
}

-- Python tuple type
export type PyTuple = PyObject & {
    __type: "tuple", 
    __value: {PyObject},
}

-- Python set type
export type PySet = PyObject & {
    __type: "set",
    __value: {[PyObject]: boolean},
}

-- TODO: Implement collection creation and methods

return Collections
