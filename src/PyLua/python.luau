-- PyLua Main API
-- Public interface for the PyLua bytecode system

local Python = {}

-- Import components
local compiler = require('./compiler/compiler')
local bytecodeExecutor = require('./vm/bytecode_executor')

local types = require('./core/types')
type Bytecode = types.Bytecode
type ExecutionOptions = types.ExecutionOptions
type Any = types.Any

-- Compile Python source code to bytecode
function Python.compile(sourceString)
    if type(sourceString) ~= "string" then
        error("Python.compile() requires a string argument")
    end
    
    return compiler.compile(sourceString)
end

-- Execute bytecode and return the result
function Python.runBytecode(bytecode, options: ExecutionOptions)
    if type(bytecode) ~= "table" then
        error("Python.runBytecode() requires a bytecode table")
    end
    
    return bytecodeExecutor.execute(bytecode, options)
end

-- Compile and execute Python source code in one step
function Python.execute(sourceString, options: ExecutionOptions)
    local bytecode = Python.compile(sourceString)
    return Python.runBytecode(bytecode, options)
end

-- Get a variable value from execution results (compatibility function)
function Python.getVariable(variables, name)
    return bytecodeExecutor.getVariable(variables, name)
end

-- Export version information
Python.version = "0.2.2"
Python.description = "PyLua - The Python compiler for luau"

return Python
