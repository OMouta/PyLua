--!strict
-- PyLua Function Objects
-- Phase 3 - Python function implementations

local Functions = {}

local base = require('./base')
type PyObject = base.PyObject

-- Python function type
export type PyFunction = PyObject & {
    __type: "function",
    __value: {
        name: string?,
        code: any,              -- Bytecode or native function
        globals: {[string]: PyObject},
        defaults: {PyObject}?,  -- Default parameter values
        closure: {PyObject}?,   -- Closure variables
    },
}

-- TODO: Implement function objects in Phase 3
-- - Function creation
-- - Parameter binding
-- - Function calls
-- - Closures and scoping

return Functions
