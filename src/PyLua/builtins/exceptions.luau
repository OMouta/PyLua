--!strict
-- PyLua Exception Handling
-- Phase 5 - Python exception system

local Exceptions = {}

local base = require('../objects/base')
type PyObject = base.PyObject

-- Python exception base type
export type PyException = PyObject & {
    __type: "exception",
    __value: {
        message: string,
        traceback: {any}?,
    },
}

-- TODO: Implement Python exceptions in Phase 5:
-- - BaseException hierarchy
-- - Exception propagation  
-- - try/except/finally
-- - Custom exceptions

return Exceptions
