-- PyLua 0.2 Bytecode Executor
-- Virtual machine that executes PyLua bytecode

local opcodes = require(script.Parent.opcodes)
local builtins = require(script.Parent.Parent.core.builtins)
local objects = require(script.Parent.Parent.core.objects)
local Opcodes = opcodes.Opcodes
local BytecodeExecutor = {}

-- Virtual machine state
local function createVM()
    return {
        stack = {},           -- Execution stack
        stackPointer = 0,     -- Current stack position
        pc = 1,              -- Program counter (instruction pointer)
        constants = {},       -- Constants table from bytecode
        names = {},          -- Names table from bytecode
        code = {},           -- Code instructions from bytecode
        variables = {},       -- Runtime variables storage
        builtins = builtins.getBuiltins(),  -- Built-in functions from core module
        returnValue = nil,    -- Last return value
        
        -- Error handling and debugging
        sourceLines = {},     -- Original source code lines for error reporting
        debug = false,        -- Debug mode flag
    }
end

-- Error handling utilities
local function createRuntimeError(vm, errorType, message, suggestion)
    local instruction = vm.code[vm.pc]
    local lineNumber = instruction and instruction.line or "unknown"
    local sourceLine = vm.sourceLines[lineNumber] or "Source line not available"
    
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

local function debugLog(vm, message)
    if vm.debug then
        local instruction = vm.code[vm.pc]
        local lineNumber = instruction and instruction.line or "unknown"
        print(string.format("[DEBUG] PC:%d Line:%s %s", vm.pc, tostring(lineNumber), message))
    end
end

-- Stack operations with error handling
local function push(vm, value)
    vm.stackPointer = vm.stackPointer + 1
    vm.stack[vm.stackPointer] = value
    debugLog(vm, "PUSH " .. tostring(value) .. " (stack size: " .. vm.stackPointer .. ")")
end

local function pop(vm)
    if vm.stackPointer <= 0 then
        error(createRuntimeError(vm, "StackError", "Stack underflow - attempted to pop from empty stack", 
            "This is likely a compiler bug or corrupted bytecode"))
    end
    local value = vm.stack[vm.stackPointer]
    vm.stack[vm.stackPointer] = nil
    vm.stackPointer = vm.stackPointer - 1
    debugLog(vm, "POP " .. tostring(value) .. " (stack size: " .. vm.stackPointer .. ")")
    return value
end

local function peek(vm)
    if vm.stackPointer <= 0 then
        error(createRuntimeError(vm, "StackError", "Stack underflow - attempted to peek empty stack",
            "This is likely a compiler bug or corrupted bytecode"))
    end
    return vm.stack[vm.stackPointer]
end

-- Opcode handlers
local opcodeHandlers = {}

opcodeHandlers[Opcodes.LOAD_CONST] = function(vm, instruction)
    local constantIndex = instruction.arg
    local constant = vm.constants[constantIndex + 1] -- Lua arrays are 1-indexed
    push(vm, constant)
end

opcodeHandlers[Opcodes.STORE_NAME] = function(vm, instruction)
    local nameIndex = instruction.arg
    local name = vm.names[nameIndex + 1] -- Lua arrays are 1-indexed
    local value = pop(vm)
    vm.variables[name] = value
end

opcodeHandlers[Opcodes.LOAD_NAME] = function(vm, instruction)
    local nameIndex = instruction.arg
    if nameIndex < 0 or nameIndex >= #vm.names then
        error(createRuntimeError(vm, "BytecodeError", 
            "Invalid name index " .. nameIndex .. " (names table has " .. #vm.names .. " entries)",
            "This is likely a compiler bug"))
    end
    
    local name = vm.names[nameIndex + 1] -- Lua arrays are 1-indexed
    local value = vm.variables[name]
    
    -- If not found in variables, check built-ins
    if value == nil then
        value = vm.builtins[name]
    end
    
    if value == nil then
        local suggestion = "Make sure the variable is defined before using it"
        if name == "range" or name == "print" or name == "len" then
            suggestion = "This is a built-in function - check if the built-ins module is properly loaded"
        end
        error(createRuntimeError(vm, "NameError", "name '" .. name .. "' is not defined", suggestion))
    end
    
    debugLog(vm, "LOAD_NAME " .. name .. " = " .. tostring(value))
    push(vm, value)
end

-- Arithmetic operations with type checking
opcodeHandlers[Opcodes.BINARY_ADD] = function(vm, instruction)
    local b = pop(vm)
    local a = pop(vm)
    
    if type(a) == "number" and type(b) == "number" then
        push(vm, a + b)
    elseif type(a) == "string" and type(b) == "string" then
        push(vm, a .. b) -- String concatenation
    else
        error(createRuntimeError(vm, "TypeError", 
            "unsupported operand type(s) for +: '" .. type(a) .. "' and '" .. type(b) .. "'",
            "Addition requires two numbers or two strings"))
    end
end

opcodeHandlers[Opcodes.BINARY_SUB] = function(vm, instruction)
    local b = pop(vm)
    local a = pop(vm)
    
    if type(a) ~= "number" or type(b) ~= "number" then
        error(createRuntimeError(vm, "TypeError", 
            "unsupported operand type(s) for -: '" .. type(a) .. "' and '" .. type(b) .. "'",
            "Subtraction requires two numbers"))
    end
    
    push(vm, a - b)
end

opcodeHandlers[Opcodes.BINARY_MUL] = function(vm, instruction)
    local b = pop(vm)
    local a = pop(vm)
    
    if type(a) ~= "number" or type(b) ~= "number" then
        error(createRuntimeError(vm, "TypeError", 
            "unsupported operand type(s) for *: '" .. type(a) .. "' and '" .. type(b) .. "'",
            "Multiplication requires two numbers"))
    end
    
    push(vm, a * b)
end

opcodeHandlers[Opcodes.BINARY_DIV] = function(vm, instruction)
    local b = pop(vm)
    local a = pop(vm)
    
    if type(a) ~= "number" or type(b) ~= "number" then
        error(createRuntimeError(vm, "TypeError", 
            "unsupported operand type(s) for /: '" .. type(a) .. "' and '" .. type(b) .. "'",
            "Division requires two numbers"))
    end
    
    if b == 0 then
        error(createRuntimeError(vm, "ZeroDivisionError", "division by zero",
            "Check that the divisor is not zero before performing division"))
    end
    
    push(vm, a / b)
end

opcodeHandlers[Opcodes.BINARY_MOD] = function(vm, instruction)
    local b = pop(vm)
    local a = pop(vm)
    push(vm, a % b)
end

opcodeHandlers[Opcodes.BINARY_POW] = function(vm, instruction)
    local b = pop(vm)
    local a = pop(vm)
    push(vm, a ^ b)
end

-- Comparison operations
opcodeHandlers[Opcodes.COMPARE_EQ] = function(vm, instruction)
    local b = pop(vm)
    local a = pop(vm)
    push(vm, a == b)
end

opcodeHandlers[Opcodes.COMPARE_NE] = function(vm, instruction)
    local b = pop(vm)
    local a = pop(vm)
    push(vm, a ~= b)
end

opcodeHandlers[Opcodes.COMPARE_LT] = function(vm, instruction)
    local b = pop(vm)
    local a = pop(vm)
    push(vm, a < b)
end

opcodeHandlers[Opcodes.COMPARE_LE] = function(vm, instruction)
    local b = pop(vm)
    local a = pop(vm)
    push(vm, a <= b)
end

opcodeHandlers[Opcodes.COMPARE_GT] = function(vm, instruction)
    local b = pop(vm)
    local a = pop(vm)
    push(vm, a > b)
end

opcodeHandlers[Opcodes.COMPARE_GE] = function(vm, instruction)
    local b = pop(vm)
    local a = pop(vm)
    push(vm, a >= b)
end

-- Control flow operations
opcodeHandlers[Opcodes.JUMP] = function(vm, instruction)
    vm.pc = instruction.arg + 1 -- Lua arrays are 1-indexed
end

opcodeHandlers[Opcodes.JUMP_IF_FALSE] = function(vm, instruction)
    local condition = pop(vm)
    if not condition then
        vm.pc = instruction.arg + 1 -- Lua arrays are 1-indexed
    end
end

opcodeHandlers[Opcodes.JUMP_IF_TRUE] = function(vm, instruction)
    local condition = pop(vm)
    if condition then
        vm.pc = instruction.arg + 1 -- Lua arrays are 1-indexed
    end
end

-- Function call operation with enhanced error handling
opcodeHandlers[Opcodes.CALL_FUNCTION] = function(vm, instruction)
    local argCount = instruction.arg
    local args_table = {} -- Renamed to avoid confusion with a potential 'args' variable in called func
    
    -- Pop arguments from stack (in reverse order)
    for i = argCount, 1, -1 do
        args_table[i] = pop(vm)
    end
    
    local func = pop(vm) -- Function to call
    debugLog(string.format("[DEBUG CALL_FUNCTION] Attempting to call func. Type: %s, Value: %s, ArgCount: %d", type(func), tostring(func), argCount)) -- DEBUG LINE
    if #args_table > 0 then
        debugLog("[DEBUG CALL_FUNCTION] Args table content:")
        for i, v in ipairs(args_table) do
            debugLog(string.format("  args_table[%d]: Type: %s, Value: %s", i, type(v), tostring(v)))
        end
    end

    if type(func) == "function" then
        debugLog(vm, "CALL_FUNCTION with " .. argCount .. " arguments")
        
        -- IMPORTANT CHANGE HERE:
        -- The boundMethodClosure expects the args_table directly.
        -- Other functions (like builtins) expect arguments to be unpacked.
        -- We need a way to distinguish or make this consistent. 
        -- For now, let's assume if it's a product of LOAD_ATTR (our bound method), it takes the table.
        -- This is a bit of a hack. A cleaner way would be to tag functions or wrap builtins.
        -- However, the boundMethodClosure is specifically designed to take the table and unpack it internally.
        -- So, for builtins like len(obj), it should be pcall(func, obj) -> pcall(func, table.unpack(args_table))
        -- For list.append(item), bound method takes table: pcall(func, {item})

        local success, result
        -- A simple, albeit imperfect, way to check if it might be our bound method:
        -- This check is NOT robust. A better way is needed if more function types are added.
        -- For now, let's try to see if direct table passing for bound methods and unpack for others helps.
        -- The issue is that `debug_bound_method` test implies bound methods are called via CALL_FUNCTION too.
        -- The boundMethodClosure itself does table.unpack(argsTable or {}).
        -- So, all functions called via CALL_FUNCTION should have their arguments unpacked for pcall.

        success, result = pcall(func, table.unpack(args_table)) -- Universal unpacking

        if not success then
            local originalError = tostring(result)
            debugLog(string.format("[DEBUG CALL_FUNCTION] pcall FAILED. Error: %s", originalError)) -- DEBUG LINE
            error(createRuntimeError(vm, "RuntimeError", 
                "Error in function call: " .. originalError,
                "Check the function arguments and their types"))
        else
            debugLog(string.format("[DEBUG CALL_FUNCTION] pcall SUCCEEDED. Result type: %s", type(result))) -- DEBUG LINE
        end
        
        push(vm, result)
    else
        debugLog(string.format("[DEBUG CALL_FUNCTION] func is NOT a function. Type: %s, Value: %s", type(func), tostring(func))) -- DEBUG LINE
        local suggestion = "Make sure you're calling a function, not a variable"
        if type(func) == "string" then
            suggestion = "The value '" .. func .. "' is a string, not a function. Did you mean to call a function with this name?"
        end
        
        error(createRuntimeError(vm, "TypeError", 
            "'" .. tostring(func) .. "' object is not callable (type: " .. type(func) .. ")",
            suggestion))
    end
end

-- Stack manipulation
opcodeHandlers[Opcodes.POP_TOP] = function(vm, instruction)
    pop(vm)
end

opcodeHandlers[Opcodes.DUP_TOP] = function(vm, instruction)
    local value = peek(vm)
    push(vm, value)
end

-- Return operation
opcodeHandlers[Opcodes.RETURN_VALUE] = function(vm, instruction)
    vm.returnValue = pop(vm)
    vm.pc = #vm.code + 1 -- End execution
end

-- Iterator operations
opcodeHandlers[Opcodes.GET_ITER] = function(vm, instruction)
    local iterable = pop(vm)
    
    -- Create an iterator object for the iterable
    local iterator
    if type(iterable) == "table" then
        -- For lists/arrays, create a simple index-based iterator
        iterator = {
            type = "list",
            data = iterable,
            index = 1,
            length = #iterable
        }
    else
        error("Object is not iterable: " .. type(iterable))
    end
    
    push(vm, iterator)
end

opcodeHandlers[Opcodes.FOR_ITER] = function(vm, instruction)
    local iterator = peek(vm) -- Don't pop yet, we need it for the next iteration
    
    if iterator.type == "list" then
        if iterator.index <= iterator.length then
            -- Push the current value onto the stack
            push(vm, iterator.data[iterator.index])
            iterator.index = iterator.index + 1
            -- Continue to next instruction (don't jump)
        else
            -- Iterator exhausted, pop it and jump to end of loop
            pop(vm) -- Remove the iterator
            vm.pc = instruction.arg + 1 -- Jump to instruction after loop
        end
    elseif iterator.type == "sequence" then
        if iterator.index <= iterator.length then
            -- Push the current value onto the stack
            push(vm, iterator.data[iterator.index])
            iterator.index = iterator.index + 1
            -- Continue to next instruction (don't jump)
        else
            -- Iterator exhausted, pop it and jump to end of loop
            pop(vm) -- Remove the iterator
            vm.pc = instruction.arg + 1 -- Jump to instruction after loop
        end
    else
        error(createRuntimeError(vm, "RuntimeError", 
            "Unknown iterator type: " .. tostring(iterator.type),
            "This is likely a VM bug"))
    end
end

-- Python object construction operations
opcodeHandlers[Opcodes.BUILD_LIST] = function(vm, instruction)
    local count = instruction.arg
    local items = {}
    
    -- Pop items from stack in reverse order
    for i = count, 1, -1 do
        items[i] = pop(vm)
    end
    
    debugLog(vm, "BUILD_LIST with " .. count .. " items")
    push(vm, objects.createList(items))
end

opcodeHandlers[Opcodes.BUILD_DICT] = function(vm, instruction)
    local count = instruction.arg  -- Number of key-value pairs
    local items = {}
    
    -- Pop key-value pairs from stack
    -- Based on Python's typical compilation for dicts: values are pushed, then keys.
    -- For {key1: value1, key2: value2}, stack might be [..., key1, value1, key2, value2]
    -- So, popping value then key for each pair.
    for i = 1, count do
        local value = pop(vm) 
        local key = pop(vm)   
        items[key] = value
    end
    
    debugLog(vm, "BUILD_DICT with " .. count .. " pairs")
    push(vm, objects.createDict(items))
end

opcodeHandlers[Opcodes.BUILD_TUPLE] = function(vm, instruction)
    local count = instruction.arg
    local items = {}
    
    -- Pop items from stack in reverse order
    for i = count, 1, -1 do
        items[i] = pop(vm)
    end
    
    debugLog(vm, "BUILD_TUPLE with " .. count .. " items")
    push(vm, objects.createTuple(items))
end

opcodeHandlers[Opcodes.BUILD_SET] = function(vm, instruction)
    local count = instruction.arg
    local items = {} -- For a set, the Lua table stores item as key and true as value
    
    -- Pop items and add to set
    for i = 1, count do
        local item_val = pop(vm) 
        items[item_val] = true
    end
    
    debugLog(vm, "BUILD_SET with " .. count .. " items")
    push(vm, objects.createSet(items))
end

-- Indexing operations
opcodeHandlers[Opcodes.BINARY_SUBSCR] = function(vm, instruction)
    local index = pop(vm)
    local obj = pop(vm)
    
    debugLog(vm, "BINARY_SUBSCR: " .. tostring(obj) .. "[" .. tostring(index) .. "]")
    
    local success, result = pcall(objects.getItem, obj, index)
    if not success then
        error(createRuntimeError(vm, "IndexError", result, 
            "Check that the index is within bounds and the object supports indexing"))
    end
    
    push(vm, result)
end

opcodeHandlers[Opcodes.STORE_SUBSCR] = function(vm, instruction)
    local value = pop(vm)  -- Top of stack: value to assign
    local index = pop(vm)  -- Middle: index/key
    local obj = pop(vm)    -- Bottom: object to assign to
    
    debugLog(vm, "STORE_SUBSCR: " .. tostring(obj) .. "[" .. tostring(index) .. "] = " .. tostring(value))
    
    local success, errorMsg = pcall(objects.setItem, obj, index, value)
    if not success then
        error(createRuntimeError(vm, "TypeError", errorMsg,
            "Check that the object supports item assignment and the index is valid"))
    end
end

-- Method and attribute operations
opcodeHandlers[Opcodes.LOAD_ATTR] = function(vm, instruction)
    local nameIndex = instruction.arg
    local attrName = vm.names[nameIndex + 1]
    local obj = pop(vm) -- The object whose attribute is being accessed

    debugLog(string.format("[DEBUG LOAD_ATTR] Start. Object type: %s, Attr name: '%s'", type(obj), attrName)) -- DEBUG LINE
    if type(obj) == "table" and obj.__type then -- Ensure obj.__type exists for PyObjects
        debugLog(string.format("[DEBUG LOAD_ATTR] Object is a table. obj.__type: %s", tostring(obj.__type))) -- DEBUG LINE

        -- 1. Check for a method in __methods
        if obj.__methods and obj.__methods[attrName] then
            debugLog(string.format("[DEBUG LOAD_ATTR] Found '%s' in obj.__methods of '%s'. Type: %s", attrName, obj.__type, type(obj.__methods[attrName]))) -- DEBUG LINE
            local method = obj.__methods[attrName]
            if type(method) == "function" then
                local boundMethodClosure = function(...)
                    local actualArgsPassedToClosure = {...} -- Capture all arguments passed to the closure
                    debugLog(string.format("[DEBUG boundMethodClosure] Called for attr '%s' on obj type '%s'. Self type: %s. Args count: %d", attrName, obj.__type, type(obj), #actualArgsPassedToClosure))
                    if #actualArgsPassedToClosure > 0 then
                        for i, v_arg in ipairs(actualArgsPassedToClosure) do -- Renamed v to v_arg
                            debugLog(string.format("  arg %d: Type: %s, Value: %s", i, type(v_arg), tostring(v_arg)))
                        end
                    end
                    -- Pass self (obj) and unpacked args to the actual method
                    return method(obj, table.unpack(actualArgsPassedToClosure))
                end
                push(vm, boundMethodClosure)
                debugLog(string.format("[DEBUG LOAD_ATTR] Pushed boundMethodClosure for method '%s' of '%s'. Returning.", attrName, obj.__type)) -- DEBUG
                return -- Successfully handled as a method
            else
                -- Attribute found in __methods but is not a function.
                debugLog(string.format("[DEBUG LOAD_ATTR] Attribute '%s' in __methods of '%s' is not a function (type: %s). Falling through.", attrName, obj.__type, type(method))) -- DEBUG
            end
        else
            debugLog(string.format("[DEBUG LOAD_ATTR] Attribute '%s' not found in __methods of '%s'.", attrName, obj.__type)) -- DEBUG
        end

        -- 2. Check for an item in __dict (relevant for PyDict data, or other object attributes)
        if obj.__dict and obj.__dict[attrName] then
            debugLog(string.format("[DEBUG LOAD_ATTR] Attribute '%s' found in __dict of '%s'. Pushing value. Returning.", attrName, obj.__type)) -- DEBUG
            push(vm, obj.__dict[attrName])
            return -- Successfully handled as a direct attribute or dict item
        else
             debugLog(string.format("[DEBUG LOAD_ATTR] Attribute '%s' not found in __dict of '%s'.", attrName, obj.__type)) -- DEBUG
        end

    elseif type(obj) == "table" then -- Generic Lua table, not a PyObject (obj.__type is nil)
        if obj[attrName] ~= nil then
            debugLog(string.format("[DEBUG LOAD_ATTR] Attribute '%s' found in generic Lua table. Pushing value. Returning.", attrName)) -- DEBUG
            push(vm, obj[attrName])
            return
        end
        debugLog(string.format("[DEBUG LOAD_ATTR] Object is a generic Lua table (no __type), attribute '%s' not found.", attrName)) -- DEBUG

    else -- Object is not a table
        debugLog(string.format("[DEBUG LOAD_ATTR] Object is not a table (type: %s). Cannot get attribute '%s'.", type(obj), attrName)) -- DEBUG
    end

    -- If we reach here, the attribute was not found or not handled appropriately
    debugLog(string.format("[DEBUG LOAD_ATTR] Failed to load attribute '%s' for object type %s (value: %s). Erroring.", attrName, tostring(obj and obj.__type or type(obj)), tostring(obj))) -- DEBUG
    error(createRuntimeError(vm, "AttributeError",
        "'" .. tostring(obj and obj.__type or type(obj)) .. "' object has no attribute '" .. attrName .. "' or it's not accessible/callable as expected"))
end

opcodeHandlers[Opcodes.STORE_ATTR] = function(vm, instruction)
    local nameIndex = instruction.arg
    local attrName = vm.names[nameIndex + 1]
    local obj = pop(vm)
    local value = pop(vm)
    
    debugLog(vm, "STORE_ATTR: " .. tostring(obj) .. "." .. attrName .. " = " .. tostring(value))
    
    if type(obj) == "table" and obj.__dict then
        obj.__dict[attrName] = value
    else
        error(createRuntimeError(vm, "AttributeError",
            "'" .. (obj.__type or type(obj)) .. "' object has no attribute '" .. attrName .. "'",
            "Make sure the object supports attribute assignment"))
    end
end

opcodeHandlers[Opcodes.CALL_METHOD] = function(vm, instruction)
    local argCount = instruction.arg
    local nameIndex = instruction.target  -- Method name index
    local methodName = vm.names[nameIndex + 1]
    
    local args = {}
    -- Pop arguments
    for i = argCount, 1, -1 do
        args[i] = pop(vm)
    end
    
    local obj = pop(vm)
    
    debugLog(vm, "CALL_METHOD: " .. tostring(obj) .. "." .. methodName .. " with " .. argCount .. " args")
    
    local success, result = pcall(objects.callMethod, obj, methodName, args)
    if not success then
        error(createRuntimeError(vm, "AttributeError", result,
            "Check that the method exists and the arguments are correct"))
    end
    
    push(vm, result)
end

-- Type checking operations
opcodeHandlers[Opcodes.GET_TYPE] = function(vm, instruction)
    local obj = pop(vm)
    
    if type(obj) == "table" and obj.__type then
        push(vm, obj.__type)
    else
        -- Convert Lua types to Python type names
        local luaType = type(obj)
        if luaType == "number" then
            if obj % 1 == 0 then
                push(vm, "int")
            else
                push(vm, "float")
            end
        elseif luaType == "string" then
            push(vm, "str")
        elseif luaType == "boolean" then
            push(vm, "bool")
        elseif luaType == "nil" then
            push(vm, "NoneType")
        else
            push(vm, luaType)
        end
    end
end

-- Main execution function with comprehensive error handling
function BytecodeExecutor.execute(bytecode, options)
    options = options or {}
    local vm = createVM()
    
    -- Initialize VM with bytecode
    vm.constants = bytecode.constants or {}
    vm.names = bytecode.names or {}
    vm.code = bytecode.code or {}
    vm.sourceLines = bytecode.sourceLines or {}
    vm.debug = options.debug or false
    
    -- Validate bytecode structure
    if type(vm.code) ~= "table" or #vm.code == 0 then
        error("Invalid bytecode: code section is missing or empty")
    end
    
    if vm.debug then
        debugLog("[DEBUG] Starting execution with " .. #vm.code .. " instructions")
        debugLog("[DEBUG] Constants: " .. #vm.constants)
        debugLog("[DEBUG] Names: " .. #vm.names)
    end
    
    -- Execute instructions with error handling
    while vm.pc <= #vm.code do
        local instruction = vm.code[vm.pc]
        
        -- Validate instruction structure
        if type(instruction) ~= "table" or not instruction.op then
            error(createRuntimeError(vm, "BytecodeError", 
                "Invalid instruction at PC " .. vm.pc .. ": " .. tostring(instruction),
                "This is likely corrupted bytecode"))
        end
        
        local handler = opcodeHandlers[instruction.op]
        
        if not handler then
            error(createRuntimeError(vm, "BytecodeError", 
                "Unknown opcode: " .. tostring(instruction.op),
                "This opcode is not implemented or the bytecode is corrupted"))
        end
        
        local oldPC = vm.pc
        
        -- Execute the instruction with error context
        local success, errorMsg = pcall(function()
            handler(vm, instruction)
        end)
        
        if not success then
            -- Re-throw the error (it should already be formatted by our error handling)
            error(errorMsg)
        end
        
        -- Move to next instruction (unless a jump occurred)
        if vm.pc == oldPC then
            vm.pc = vm.pc + 1
        end
        
        -- Safety check for infinite loops in debug mode
        if vm.debug and vm.pc > #vm.code * 1000 then
            error(createRuntimeError(vm, "RuntimeError", 
                "Possible infinite loop detected (executed > " .. (#vm.code * 1000) .. " instructions)",
                "Check for infinite loops in your code"))
        end
    end
    
    if vm.debug then
        debugLog("[DEBUG] Execution completed successfully")
        debugLog("[DEBUG] Final stack size: " .. vm.stackPointer)
    end
    
    return vm.returnValue, vm.variables
end

-- Helper function to get a variable value (for compatibility with old API)
function BytecodeExecutor.getVariable(variables, name)
    return variables[name]
end

return BytecodeExecutor
