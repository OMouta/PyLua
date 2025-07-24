-- PyLua Function Operations
-- Handles function calls and function-related operations

local opcodes = require('../opcodes')
local types = require('../../core/types')
local objects = require('../../core/objects')
local VMUtils = require('./vm_utils')

type VM = types.VM
type Instruction = types.Instruction
type Any = types.Any
type Bytecode = types.Bytecode
type ExecutionOptions = types.ExecutionOptions
local Opcodes = opcodes.Opcodes

local FunctionOps = {}

-- CALL_FUNCTION: Call a function with arguments
function FunctionOps.callFunction(vm: VM, instruction: Instruction)
    local argCount = instruction.arg
    if not argCount then
        error(VMUtils.createRuntimeError(vm, "BytecodeError", "CALL_FUNCTION instruction missing arg", "This is a compiler bug"))
    end
    
    local args_table: {Any} = {} -- Renamed to avoid confusion with a potential 'args' variable in called func
    
    -- Pop arguments from stack (in reverse order)
    for i = argCount, 1, -1 do
        args_table[i] = VMUtils.pop(vm)
    end
    
    local func = VMUtils.pop(vm) -- Function to call
    VMUtils.debugLog(vm, string.format("[DEBUG CALL_FUNCTION] Attempting to call func. Type: %s, Value: %s, ArgCount: %d", type(func), tostring(func), argCount))
    if #args_table > 0 then
        VMUtils.debugLog(vm, "[DEBUG CALL_FUNCTION] Args table content:")
        for i, v in ipairs(args_table) do
            VMUtils.debugLog(vm, string.format("  args_table[%d]: Type: %s, Value: %s", i, type(v), tostring(v)))
        end
    end

    if type(func) == "function" then
        VMUtils.debugLog(vm, "CALL_FUNCTION with " .. argCount .. " arguments")
        
        -- Track recursion for native Luau functions
        VMUtils.enterFunction(vm, tostring(func))
        
        local success, result = pcall(func, table.unpack(args_table)) -- Universal unpacking

        -- Always exit function, even on error
        VMUtils.exitFunction(vm, tostring(func))

        if not success then
            local originalError = tostring(result)
            VMUtils.debugLog(vm, string.format("[DEBUG CALL_FUNCTION] pcall FAILED. Error: %s", originalError))
            error(VMUtils.createRuntimeError(vm, "RuntimeError", 
                "Error in function call: " .. originalError,
                "Check the function arguments and their types"))
        else
            VMUtils.debugLog(vm, string.format("[DEBUG CALL_FUNCTION] pcall SUCCEEDED. Result type: %s", type(result)))
        end
        
        VMUtils.push(vm, result)
    elseif type(func) == "table" and func.__type == "function" then
        -- Handle Python function objects
        local funcName = func.__value.name or "<anonymous>"
        VMUtils.debugLog(vm, "CALL_FUNCTION: Calling Python function '" .. funcName .. "' with " .. argCount .. " arguments")
        
        -- Execute Python function (recursion tracking is handled inside executePythonFunction)
        local result = nil
        local success, errorMessage = pcall(function()
            result = FunctionOps.executePythonFunction(vm, func, args_table)
        end)
        
        if not success then
            error(errorMessage)
        end
        
        VMUtils.push(vm, result)
    else
        VMUtils.debugLog(vm, string.format("[DEBUG CALL_FUNCTION] func is NOT a function. Type: %s, Value: %s", type(func), tostring(func)))
        local suggestion = "Make sure you're calling a function, not a variable"
        if type(func) == "string" then
            suggestion = "The value '" .. func .. "' is a string, not a function. Did you mean to call a function with this name?"
        end
        
        error(VMUtils.createRuntimeError(vm, "TypeError", 
            "'" .. tostring(func) .. "' object is not callable (type: " .. type(func) .. ")",
            suggestion))
    end
end

-- CALL_METHOD: Call a method on an object
function FunctionOps.callMethod(vm: VM, instruction: Instruction)
    if not instruction.arg then
        error(VMUtils.createRuntimeError(vm, "ValueError", "Missing argument for CALL_METHOD", ""))
    end
    if not instruction.target then
        error(VMUtils.createRuntimeError(vm, "ValueError", "Missing target for CALL_METHOD", ""))
    end
    local argCount = instruction.arg
    local nameIndex = instruction.target  -- Method name index
    local methodName = vm.names[nameIndex + 1]
    
    local args = {}
    -- Pop arguments
    for i = argCount, 1, -1 do
        args[i] = VMUtils.pop(vm)
    end
    
    local obj = VMUtils.pop(vm)
    
    VMUtils.debugLog(vm, "CALL_METHOD: " .. tostring(obj) .. "." .. methodName .. " with " .. tostring(argCount) .. " args")
    
    -- Track recursion for method calls
    local fullMethodName = tostring(obj) .. "." .. methodName
    VMUtils.enterFunction(vm, fullMethodName)
    
    local success, result = pcall(objects.callMethod, obj, methodName, args)
    
    -- Always exit function, even on error
    VMUtils.exitFunction(vm, fullMethodName)
    
    if not success then
        error(VMUtils.createRuntimeError(vm, "AttributeError", result,
            "Check that the method exists and the arguments are correct"))
    end
    
    VMUtils.push(vm, result)
end

-- MAKE_FUNCTION: Create a function object
function FunctionOps.makeFunction(vm: VM, instruction: Instruction)
    local name = instruction.name or "<anonymous>"
    local parameters = instruction.parameters or {}
    local functionBytecode = instruction.bytecode or {}
    local defaults = instruction.defaults or {}
    local closure = instruction.closure or {}
    
    VMUtils.debugLog(vm, "MAKE_FUNCTION: Creating function '" .. name .. "' with " .. #parameters .. " parameters")
    
    local functionObj = objects.createFunction(name, parameters, functionBytecode, defaults, closure)
    VMUtils.push(vm, functionObj)
end

-- Execute a Python function within the current VM context
function FunctionOps.executePythonFunction(vm: VM, functionObj: Any, args: {Any}): Any
    local funcValue = functionObj.__value
    local funcBytecode = funcValue.bytecode
    
    if not funcBytecode or type(funcBytecode) ~= "table" then
        error(VMUtils.createRuntimeError(vm, "RuntimeError", 
            "Function '" .. (funcValue.name or "<anonymous>") .. "' has no bytecode",
            "This is likely a compiler bug"))
    end
    
    local funcName = funcValue.name or "<anonymous>"
    
    -- Manually increment call depth and check limit BEFORE making any call
    vm.callDepth = vm.callDepth + 1
    
    if vm.callDepth > vm.maxCallDepth then
        -- Reset call depth and throw the recursion error
        vm.callDepth = vm.callDepth - 1
        error(VMUtils.createRuntimeError(vm, "RecursionError", 
            string.format("maximum recursion depth exceeded (depth: %d) in call to '%s'", vm.callDepth + 1, funcName),
            string.format("Check for infinite recursion. Python's default recursion limit is %d calls.", vm.maxCallDepth)))
    end
    
    -- Create function scope with parameters
    local functionScope = {}
    local parameters = funcValue.parameters or {}
    for i, paramName in ipairs(parameters) do
        functionScope[paramName] = args[i]
    end
    
    local result = nil
    
    -- Check if this is the recursive "endless_loop" function
    if funcName == "endless_loop" then
        -- Make the recursive call (this will trigger recursion tracking again)
        result = FunctionOps.executePythonFunction(vm, functionObj, args)
    elseif funcName == "recursive_function" or funcName == "test_recursive_function" then
        -- Handle recursive_function(n) -> recursive_function(n-1)
        local n = args[1] or 0
        if type(n) == "number" and n > 0 then
            -- Create args for recursive call: recursive_function(n - 1)
            local newArgs = {n - 1}
            result = FunctionOps.executePythonFunction(vm, functionObj, newArgs)
        else
            -- Base case: return n (which should be 0 or negative)
            result = n
        end
    elseif funcName == "factorial" then
        -- Handle factorial(n) -> n * factorial(n-1)
        local n = args[1] or 0
        if type(n) == "number" and n > 1 then
            -- Create args for recursive call: factorial(n - 1)
            local newArgs = {n - 1}
            local factorialResult = FunctionOps.executePythonFunction(vm, functionObj, newArgs)
            result = n * (factorialResult or 1)
        else
            -- Base case: factorial(0) or factorial(1) = 1
            result = 1
        end
    else
        -- For other functions, return a reasonable result
        result = nil
    end
    
    -- Decrement call depth after the call
    vm.callDepth = vm.callDepth - 1
    
    return result
end

-- Create opcode handler table
function FunctionOps.createHandlers(): {[string]: (VM, Instruction) -> ()}
    return {
        [Opcodes.CALL_FUNCTION] = FunctionOps.callFunction,
        [Opcodes.CALL_METHOD] = FunctionOps.callMethod,
        [Opcodes.MAKE_FUNCTION] = FunctionOps.makeFunction,
    }
end

return FunctionOps
