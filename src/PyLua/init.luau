--!strict
-- PyLua v0.3 - Python Interpreter for Luau
-- Main API module with Lupa-inspired interface (inverse: Python-in-Luau)

local PyLua = {}

-- Version information
PyLua.version = "0.3.0-dev"
PyLua.description = "PyLua - Embedded Python interpreter for Luau"

-- Import core components (will be implemented in later phases)
-- local lexer = require('./lexer')
-- local parser = require('./parser')
-- local compiler = require('./compiler')
-- local vm = require('./vm/interpreter')

-- Type definitions for the API
export type RuntimeOptions = {
	debug: boolean?,
	timeout: number?,
	maxRecursion: number?,
}

export type Runtime = {
	-- Core execution methods
	execute: (self: Runtime, code: string) -> (),
	eval: (self: Runtime, code: string) -> any,

	-- Advanced methods
	compile: (self: Runtime, code: string) -> any, -- Will return bytecode
	runBytecode: (self: Runtime, bytecode: any) -> any,

	-- Environment access
	globals: (self: Runtime) -> { [string]: any },
	setGlobal: (self: Runtime, name: string, value: any) -> (),
	getGlobal: (self: Runtime, name: string) -> any,

	-- Internal state (private)
	_options: RuntimeOptions,
	_globals: { [string]: any },
	_debug: boolean,
}

-- Runtime class implementation
local Runtime = {}
Runtime.__index = Runtime

-- Create a new Python runtime instance
function PyLua.new(options: RuntimeOptions?): Runtime
	local opts: RuntimeOptions = options or {}

	local runtime = {
		_options = opts,
		_globals = {},
		_debug = if opts.debug ~= nil then opts.debug else false,
	}

	setmetatable(runtime, Runtime)
	return runtime :: any -- Cast to bypass type checker temporarily
end

-- Execute Python code without returning a value (for statements)
function Runtime:execute(code: string)
	if type(code) ~= "string" then
		error("Runtime.execute() requires a string argument", 2)
	end

	-- TODO: Implement the full pipeline
	-- 1. Lexer: code -> tokens
	-- 2. Parser: tokens -> AST
	-- 3. Compiler: AST -> bytecode
	-- 4. VM: execute bytecode

	error("Not implemented yet - Phase 1 in progress", 2)
end

-- Evaluate Python expression and return the result
function Runtime:eval(code: string): any
	if type(code) ~= "string" then
		error("Runtime.eval() requires a string argument", 2)
	end

	-- TODO: Implement the full pipeline for expressions
	error("Not implemented yet - Phase 1 in progress", 2)
end

-- Compile Python source to bytecode (advanced API)
function Runtime:compile(code: string): any
	if type(code) ~= "string" then
		error("Runtime.compile() requires a string argument", 2)
	end

	-- TODO: Implement compilation pipeline
	error("Not implemented yet - Phase 1 in progress", 2)
end

-- Execute pre-compiled bytecode
function Runtime:runBytecode(bytecode: any): any
	if type(bytecode) ~= "table" then
		error("Runtime.runBytecode() requires a bytecode table", 2)
	end

	-- TODO: Implement bytecode execution
	error("Not implemented yet - Phase 1 in progress", 2)
end

-- Access the global environment
function Runtime:globals(): { [string]: any }
	return self._globals
end

-- Set a global variable
function Runtime:setGlobal(name: string, value: any)
	if type(name) ~= "string" then
		error("Runtime.setGlobal() requires a string name", 2)
	end

	self._globals[name] = value
end

-- Get a global variable
function Runtime:getGlobal(name: string): any
	if type(name) ~= "string" then
		error("Runtime.getGlobal() requires a string name", 2)
	end

	return self._globals[name]
end

-- Backward compatibility functions (deprecated)
-- These will be removed in a future version
function PyLua.execute(code: string)
	warn("PyLua.execute() is deprecated. Use PyLua.new():execute() instead.")
	local runtime = PyLua.new()
	runtime:execute(code)
end

function PyLua.eval(code: string): any
	warn("PyLua.eval() is deprecated. Use PyLua.new():eval() instead.")
	local runtime = PyLua.new()
	return runtime:eval(code)
end

return PyLua
