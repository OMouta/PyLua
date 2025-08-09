--!strict
-- PyLua Base Python Object
-- Phase 3 - Python object model foundation

local Base = {}

-- Base Python object type
export type PyObject = {
	__type: string, -- Python type name
	__value: any, -- Actual Luau value
	__dict: { [string]: PyObject }?, -- Object attributes
	__class: PyObject?, -- Object's class (for future use)
}

-- Create a new Python object
function Base.newPyObject(typeName: string, value: any): PyObject
	return {
		__type = typeName,
		__value = value,
		__dict = {},
	}
end

-- Get the Python type name of an object
function Base.getType(obj: PyObject): string
	return obj.__type
end

-- Get the Luau value of a Python object
function Base.getValue(obj: PyObject): any
	return obj.__value
end

-- TODO: Implement full object model in Phase 3
-- - Attribute access (__getattr__, __setattr__)
-- - Method resolution
-- - Type checking and conversion
-- - Object protocols (__str__, __repr__, etc.)

return Base
