-- PyLua VM Utilities
-- Error handling, debugging, and stack operations

local types = require('../../core/types')

type VM = types.VM
type Any = types.Any

local VMUtils = {}

-- Error handling utilities
function VMUtils.createRuntimeError(vm: VM, errorType: string, message: string, suggestion: string?): string
    local instruction = vm.code[vm.pc]
    local lineNumber = instruction and instruction.line or "unknown"
    local sourceLine = "Source line not available"
    
    if lineNumber ~= "unknown" and type(lineNumber) == "number" then
        sourceLine = vm.sourceLines[lineNumber] or "Source line not available"
    elseif lineNumber ~= "unknown" and type(lineNumber) == "string" then
        sourceLine = vm.sourceLines[tonumber(lineNumber) or 1] or "Source line not available"
    end
    
    local errorMessage = string.format(
        "%s: %s\n  at line %s: %s",
        errorType,
        message,
        tostring(lineNumber),
        sourceLine
    )
    
    if suggestion then
        errorMessage = errorMessage .. "\n  Suggestion: " .. suggestion
    end
    
    return errorMessage
end

function VMUtils.debugLog(vm: VM, message: string)
    if vm.debug then
        local instruction = vm.code[vm.pc]
        local lineNumber = instruction and instruction.line or "unknown"
        print(string.format("[DEBUG] PC:%d Line:%s %s", vm.pc, tostring(lineNumber), message))
    end
end

-- Stack operations with error handling
function VMUtils.push(vm: VM, value: Any)
    vm.stackPointer = vm.stackPointer + 1
    vm.stack[vm.stackPointer] = value
    VMUtils.debugLog(vm, "PUSH " .. tostring(value) .. " (stack size: " .. vm.stackPointer .. ")")
end

function VMUtils.pop(vm: VM): Any
    if vm.stackPointer <= 0 then
        error(VMUtils.createRuntimeError(vm, "StackError", "Stack underflow - attempted to pop from empty stack", 
            "This is likely a compiler bug or corrupted bytecode"))
    end
    local value = vm.stack[vm.stackPointer]
    vm.stack[vm.stackPointer] = nil
    vm.stackPointer = vm.stackPointer - 1
    VMUtils.debugLog(vm, "POP " .. tostring(value) .. " (stack size: " .. vm.stackPointer .. ")")
    return value
end

function VMUtils.peek(vm: VM): Any
    if vm.stackPointer <= 0 then
        error(VMUtils.createRuntimeError(vm, "StackError", "Stack underflow - attempted to peek empty stack",
            "This is likely a compiler bug or corrupted bytecode"))
    end
    return vm.stack[vm.stackPointer]
end

-- Recursion limit utilities
function VMUtils.enterFunction(vm: VM, functionName: string?)
    vm.callDepth = vm.callDepth + 1
    
    if vm.callDepth > vm.maxCallDepth then
        local funcDesc = functionName and ("'" .. functionName .. "'") or "anonymous function"
        error(VMUtils.createRuntimeError(vm, "RecursionError", 
            string.format("maximum recursion depth exceeded (depth: %d) in call to %s", vm.callDepth, funcDesc),
            string.format("Check for infinite recursion. Python's default recursion limit is %d calls.", vm.maxCallDepth)))
    end
    
    VMUtils.debugLog(vm, string.format("ENTER_FUNCTION %s (call depth: %d)", functionName or "<anonymous>", vm.callDepth))
end

function VMUtils.exitFunction(vm: VM, functionName: string?)
    if vm.callDepth > 0 then
        vm.callDepth = vm.callDepth - 1
        VMUtils.debugLog(vm, string.format("EXIT_FUNCTION %s (call depth: %d)", functionName or "<anonymous>", vm.callDepth))
    end
end

function VMUtils.setRecursionLimit(vm: VM, limit: number)
    if limit < 1 then
        error(VMUtils.createRuntimeError(vm, "ValueError", "recursion limit must be a positive integer", ""))
    end
    vm.maxCallDepth = limit
    VMUtils.debugLog(vm, string.format("RECURSION_LIMIT set to %d", limit))
end

function VMUtils.getRecursionLimit(vm: VM): number
    return vm.maxCallDepth
end

return VMUtils
