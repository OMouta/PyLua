local PyLua = {}

-- Version information
PyLua.version = "0.3.0"
PyLua.description = "PyLua - Embedded Python interpreter for Luau"

-- Import core components
local lexer = require("@self/lexer")
local parser = require("@self/parser")
local compiler = require("@self/compiler")
local vm = require("@self/vm/interpreter")
local builtinFunctions = require("@self/builtins/functions")
local interop = require("@self/interop/bridge")
local Base = require("@self/objects/base")
local imports = require("@self/vm/imports")
local Module = require("@self/objects/module")

type _ClassBindingOptions = {
	pyTypeName: string,
	typeofName: string?,
	predicate: ((value: any) -> boolean)?,
	bindSelf: boolean?,
	getAttr: ((target: any, attr: string) -> any?)?,
	setAttr: ((target: any, attr: string, value: any) -> ())?,
	toLuau: ((target: any, visited: { [any]: any }) -> any)?,
}

export type ClassBindingOptions = _ClassBindingOptions

-- Type definitions for the API
export type RuntimeOptions = {
	debug: boolean?,
	timeout: number?,
	maxRecursion: number?,
	builtins: { [string]: any }?,
	searchPath: { string }?,
	nativeModules: { [string]: any }?,
	mounts: { [string]: { [string]: string } }?,
	fileSystem: imports.FileSystem?,
	enableFilesystem: boolean?,
	policy: imports.Policy?,
}

export type Runtime = {
	-- Core execution methods
	execute: (self: Runtime, code: string) -> (),
	eval: (self: Runtime, code: string) -> any,
	compile: (self: Runtime, code: string) -> any, -- Will return bytecode
	runBytecode: (self: Runtime, bytecode: any) -> any,

	-- Environment access
	globals: (self: Runtime) -> { [string]: any },
	setGlobal: (self: Runtime, name: string, value: any) -> (),
	getGlobal: (self: Runtime, name: string) -> any,
	getGlobalPy: (self: Runtime, name: string) -> any,

	-- Internal state (private)
	_options: RuntimeOptions,
	_globals: { [string]: any },
	_globalsProxy: { [string]: any },
	_builtins: { [string]: any },
	_debug: boolean,
	_importer: any,
}

-- Runtime class implementation
local Runtime = {}
Runtime.__index = Runtime

-- Create a new Python runtime instance
function PyLua.new(options: RuntimeOptions?): Runtime
	local opts: RuntimeOptions = options or {}

	local globalsStore: { [string]: any } = {}
	local globalsProxy: { [string]: any } = {}

	local proxyMeta = {}

	function proxyMeta.__index(_: any, key: string)
		local stored = globalsStore[key]
		if stored == nil then
			return nil
		end
		return interop.pyToLuau(stored)
	end

	function proxyMeta.__newindex(_: any, key: string, value: any)
		if value == nil then
			globalsStore[key] = nil
			return
		end
		globalsStore[key] = interop.luauToPy(value)
	end

	function proxyMeta.__pairs()
		local function iterator(state, lastKey)
			local nextKey, stored = next(state, lastKey)
			if nextKey == nil then
				return nil
			end
			return nextKey, interop.pyToLuau(stored)
		end
		return iterator, globalsStore, nil
	end

	setmetatable(globalsProxy, proxyMeta)

	local runtime = {
		_options = opts,
		_globals = globalsStore,
		_globalsProxy = globalsProxy,
		_builtins = opts.builtins or builtinFunctions.createBuiltins(),
		_debug = if opts.debug ~= nil then opts.debug else false,
		_importer = nil :: any,
	}

	local nativeModules = nil
	if opts.nativeModules then
		nativeModules = {}
		for k, v in pairs(opts.nativeModules) do
			if type(v) == "table" and not (v.__type or v.__value) then
				local mod = Module.new(k, nil)
				local dict = mod.__dict :: { [string]: any }
				for attr, val in pairs(v) do
					dict[attr] = interop.luauToPy(val)
				end
				nativeModules[k] = mod
			else
				nativeModules[k] = interop.luauToPy(v)
			end
		end
	end

	local importSystem = imports.new({
		builtins = runtime._builtins,
		searchPath = opts.searchPath,
		nativeModules = nativeModules,
		mounts = opts.mounts,
		fileSystem = opts.fileSystem,
		enableFilesystem = opts.enableFilesystem,
		policy = opts.policy,
	})
	runtime._importer = importSystem

	importSystem:setExecutor(function(code, filename, modGlobals)
		-- 1. Lexer: code -> tokens
		local tokens = lexer.tokenize(code)

		-- 2. Parser: tokens -> AST
		local ast = parser.parse(tokens)

		-- 3. Compiler: AST -> bytecode
		local bytecode = compiler.compile(ast)

		-- 4. VM: execute bytecode
		vm.execute(bytecode.bytecode, modGlobals, runtime._builtins, bytecode.constants, bytecode.names)
	end)

	-- Add __import__ to builtins
	local function importWrapper(args: { any }?)
		if not args or #args < 1 then
			error("TypeError: __import__() takes at least 1 argument (0 given)", 2)
		end
		local name = args[1]
		if name.__type ~= "str" then
			error("TypeError: __import__() argument 1 must be string, not " .. name.__type, 2)
		end
		local globals = args[2]
		local locals = args[3]
		local fromlist = args[4]
		local level = args[5]

		local levelNum = 0
		if level and level.__type == "int" then
			levelNum = level.__value
		end

		return importSystem:importModule(name.__value, globals, locals, fromlist, levelNum)
	end

	local builtinType = Base.getTypeObject("builtin_function_or_method")
	local importBuiltin = {
		__type = "builtin_function_or_method",
		__value = {
			self = nil,
			name = "__import__",
			func = function(_self, args)
				return importWrapper(args)
			end,
		},
		__dict = {},
		__typeobj = builtinType,
	}

	runtime._builtins["__import__"] = importBuiltin

	local function initGlobal(name: string, value: any)
		runtime._globals[name] = interop.luauToPy(value)
	end

	initGlobal("__pylua_version__", PyLua.version)
	initGlobal("__name__", "__main__")
	initGlobal("__doc__", nil)
	initGlobal("__package__", nil)
	initGlobal("__loader__", nil)
	initGlobal("__spec__", nil)

	-- Set metatable for method access
	setmetatable(runtime, Runtime)
	return runtime :: any -- Cast to bypass type checker temporarily
end

-- Execute Python code without returning a value (for statements)
function Runtime:execute(code: string)
	if type(code) ~= "string" then
		error("Runtime.execute() requires a string argument", 2)
	end

	-- 1. Lexer: code -> tokens
	local tokens = lexer.tokenize(code)

	-- 2. Parser: tokens -> AST
	local ast = parser.parse(tokens)

	-- 3. Compiler: AST -> bytecode
	local bytecode = compiler.compile(ast)

	-- 4. VM: execute bytecode
	vm.execute(bytecode.bytecode, self._globals, self._builtins, bytecode.constants, bytecode.names)
end

-- Evaluate Python expression and return the result
function Runtime:eval(code: string): any
	if type(code) ~= "string" then
		error("Runtime.eval() requires a string argument", 2)
	end

	-- 1. Lexer: code -> tokens
	local tokens = lexer.tokenize(code)

	-- 2. Parser: tokens -> Expression AST (eval returns expression value)
	local ast = parser.parseExpression(tokens)

	-- 3. Compiler: AST -> bytecode
	local bytecode = compiler.compile(ast)

	-- 4. VM: execute bytecode
	local result = vm.execute(bytecode.bytecode, self._globals, self._builtins, bytecode.constants, bytecode.names)

	return result
end

-- Compile Python source to bytecode
function Runtime:compile(code: string): any
	if type(code) ~= "string" then
		error("Runtime.compile() requires a string argument", 2)
	end

	-- 1. Lexer: code -> tokens
	local tokens = lexer.tokenize(code)

	-- 2. Parser: tokens -> AST
	local ast = parser.parse(tokens)

	-- 3. Compiler: AST -> bytecode
	local bytecode = compiler.compile(ast)

	return bytecode
end

-- Execute pre-compiled bytecode
function Runtime:runBytecode(bytecode: any): any
	if type(bytecode) ~= "table" then
		error("Runtime.runBytecode() requires a bytecode table", 2)
	end

	return vm.execute(bytecode.bytecode, self._globals, self._builtins, bytecode.constants, bytecode.names)
end

-- Access the global environment
function Runtime:globals(): { [string]: any }
	return self._globalsProxy
end

-- Set a global variable
function Runtime:setGlobal(name: string, value: any)
	if type(name) ~= "string" then
		error("Runtime.setGlobal() requires a string name", 2)
	end

	if value == nil then
		self._globals[name] = nil
		return
	end

	self._globals[name] = interop.luauToPy(value)
end

-- Get a global variable
function Runtime:getGlobal(name: string): any
	if type(name) ~= "string" then
		error("Runtime.getGlobal() requires a string name", 2)
	end

	local stored = self._globals[name]
	if stored == nil then
		return nil
	end
	return interop.pyToLuau(stored)
end

function Runtime:getGlobalPy(name: string): any
	if type(name) ~= "string" then
		error("Runtime.getGlobalPy() requires a string name", 2)
	end

	local stored = self._globals[name]
	if stored == nil then
		return nil
	end
	if typeof(stored) == "table" and stored.__nil then
		return nil
	end
	return stored
end

function PyLua.registerClassBinding(options: ClassBindingOptions)
	interop.registerClassBinding(options)
end

function PyLua.clearClassBindings()
	interop.clearClassBindings()
end

-- Backward compatibility functions (deprecated)
-- These will be removed in a future version
function PyLua.execute(code: string)
	print("PyLua.execute() is deprecated. Use PyLua.new():execute() instead.")
	local runtime = PyLua.new()
	runtime:execute(code)
end

function PyLua.eval(code: string): any
	print("PyLua.eval() is deprecated. Use PyLua.new():eval() instead.")
	local runtime = PyLua.new()
	return runtime:eval(code)
end

return PyLua
