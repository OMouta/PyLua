-- PyLua Main API - Runtime-based architecture inspired by Lupa
local PyLua = {}

-- Import components
local compiler = require('@self/compiler/compiler')
local bytecodeExecutor = require('@self/vm/bytecode_executor')
local types = require('@self/core/types')

type Runtime = types.Runtime
type Bytecode = types.Bytecode
type ExecutionOptions = types.ExecutionOptions

-- Runtime class definition
local Runtime = {}
Runtime.__index = Runtime

-- Create a new Python runtime instance
function PyLua.new(options: {debug: boolean?, timeout: number?}?): Runtime

    -- Handle nil options case
    if options == nil then
        options = {}
    end
    
    local debug = false
    local timeout = nil
    
    -- Use rawget to avoid type checker issues
    if type(options) == "table" then
        local optDebug = rawget(options, "debug")
        local optTimeout = rawget(options, "timeout")
        
        if optDebug ~= nil then
            debug = optDebug
        end
        if optTimeout ~= nil then
            timeout = optTimeout
        end
    end
    
    local runtime = {
        _options = options,
        _globals = {} :: any,  -- Cast to any to allow dynamic property addition
        _debug = debug,
        _timeout = timeout
    }
    
    setmetatable(runtime, Runtime)
    return runtime :: any  -- Cast to any to avoid type conflicts
end

-- Runtime method: Evaluate Python code and return result
function Runtime:eval(code)
    if type(code) ~= "string" then
        error("runtime.eval() requires a string argument")
    end
    
    local bytecode = compiler.compile(code)
    if not bytecode then
        error("Python compilation failed")
    end
    
    local result = bytecodeExecutor.execute(bytecode, {
        debug = self._debug,
        globals = self._globals,
        mode = "eval"  -- Use eval mode to capture stack top as return value
    })
    
    if not result then
        error("Python execution failed")
    end
    
    -- Update our globals with any new variables
    if self._globals then
        for name, value in pairs(result.variables) do
            self._globals[name] = value
        end
    end
    
    -- Return the actual return value, or nil if no value was produced
    return result.returnValue
end

-- Runtime method: Execute Python code without return value
function Runtime:execute(code)
    if type(code) ~= "string" then
        error("runtime.execute() requires a string argument")
    end
    
    local bytecode = compiler.compile(code)
    if not bytecode then
        error("Python compilation failed")
    end
    
    local result = bytecodeExecutor.execute(bytecode, {
        debug = self._debug,
        globals = self._globals,
        mode = "exec"  -- Use exec mode to discard unused stack values
    })
    
    if not result then
        error("Python execution failed")
    end
    
    -- Execute doesn't return a value, it's for side effects only
    -- But we update our globals with any new variables
    if self._globals then
        for name, value in pairs(result.variables) do
            self._globals[name] = value
        end
    end
end

-- Runtime method: Access global environment (like lua.globals())
function Runtime:globals()
    return self._globals
end

-- Advanced API: Compile Python source code to bytecode
function Runtime:compile(code)
    if type(code) ~= "string" then
        error("runtime.compile() requires a string argument")
    end
    
    return compiler.compile(code)
end

-- Advanced API: Execute pre-compiled bytecode
function Runtime:runBytecode(bytecode, options)
    if type(bytecode) ~= "table" then
        error("runtime.runBytecode() requires a bytecode table")
    end
    
    options = options or {}
    
    -- Use rawget to avoid type checker issues
    local debugOption = rawget(options, "debug")
    
    -- Merge runtime options with call-specific options
    local execOptions = {
        debug = debugOption or self._debug,
        globals = self._globals,
        mode = "exec"  -- Default to exec mode for explicit bytecode execution
    }
    
    return bytecodeExecutor.execute(bytecode, execOptions)
end

-- Backward compatibility functions (deprecated, will be removed in v0.4)
function PyLua.compile(sourceString)
    warn("PyLua.compile() is deprecated. Use PyLua.new():compile() instead.")
    local runtime = PyLua.new({})
    return (runtime :: any):compile(sourceString)
end

function PyLua.runBytecode(bytecode, options)
    warn("PyLua.runBytecode() is deprecated. Use PyLua.new():runBytecode() instead.")
    local runtime = PyLua.new({})
    return (runtime :: any):runBytecode(bytecode, options)
end

function PyLua.execute(sourceString, options)
    warn("PyLua.execute() is deprecated. Use PyLua.new():eval() or :execute() instead.")
    local runtime = PyLua.new({})
    return (runtime :: any):eval(sourceString)
end

function PyLua.getVariable(variables, name)
    warn("PyLua.getVariable() is deprecated. Variables are handled automatically in v0.3.")
    return bytecodeExecutor.getVariable(variables, name)
end

-- Export version information
PyLua.version = "0.3.0"
PyLua.description = "PyLua - Embedded Python interpreter for Luau"

return PyLua
