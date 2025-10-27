local Functions = {}

local Base = require("./base")
local Instructions = require("../bytecode/instructions")

type PyObject = Base.PyObject
type Instruction = Instructions.Instruction

-- Function code object (similar to CPython's code object)
export type PyCode = {
	name: string, -- Function name
	argcount: number, -- Number of positional arguments
	kwonlyargcount: number, -- Number of keyword-only arguments
	varnames: { [number]: string }, -- Local variable names (array)
	bytecode: { Instruction }, -- Compiled bytecode
	constants: { [number]: any }, -- Constants used in function (array)
	names: { [number]: string }, -- Global names referenced (array)
	defaults: { PyObject }?, -- Default parameter values
	filename: string?, -- Source filename
	firstlineno: number?, -- First line number in source
	isGenerator: boolean?,
}

-- Python function type
export type PyFunction = PyObject & {
	__type: "function",
	__value: {
		name: string?,
		code: PyCode, -- Function code object
		globals: { [string]: PyObject }, -- Global namespace
		defaults: { PyObject }?, -- Default parameter values
		closure: { PyObject }?, -- Closure variables
	},
}

-- Create a new Python function object
function Functions.newFunction(
	code: PyCode,
	globals: { [string]: PyObject },
	defaults: { PyObject }?,
	closure: { PyObject }?
): PyFunction
	local func: PyFunction = Base.newPyObject("function", {
		name = code.name,
		code = code,
		globals = globals,
		defaults = defaults,
		closure = closure,
	}) :: PyFunction

	return func
end

-- Create a code object
function Functions.newCode(
	name: string,
	argcount: number,
	kwonlyargcount: number,
	varnames: { [number]: string },
	bytecode: { Instruction },
	constants: { [number]: any },
	names: { [number]: string },
	defaults: { PyObject }?,
	filename: string?,
	firstlineno: number?,
	isGenerator: boolean?
): PyCode
	return {
		name = name,
		argcount = argcount,
		kwonlyargcount = kwonlyargcount,
		varnames = varnames,
		bytecode = bytecode,
		constants = constants,
		names = names,
		defaults = defaults,
		filename = filename,
		firstlineno = firstlineno,
		isGenerator = isGenerator,
	}
end

-- Check if an object is a function
function Functions.isFunction(obj: PyObject): boolean
	return obj.__type == "function"
end

-- Get function name
function Functions.getFunctionName(func: PyFunction): string
	return func.__value.name or "<anonymous>"
end

-- Get function code object
function Functions.getFunctionCode(func: PyFunction): PyCode
	return func.__value.code
end

return Functions
