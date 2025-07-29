-- PyLua Memory Operations
-- Handles loading/storing constants, names, and variables

local opcodes = require('../opcodes')
local types = require('../../core/types')
local VMUtils = require('./vm_utils')

type VM = types.VM
type Instruction = types.Instruction
local Opcodes = opcodes.Opcodes

local MemoryOps = {}

-- LOAD_CONST: Load a constant value onto the stack
function MemoryOps.loadConst(vm: VM, instruction: Instruction)
    local constantIndex = instruction.arg
    if not constantIndex then
        error(VMUtils.createRuntimeError(vm, "BytecodeError", "LOAD_CONST instruction missing arg", "This is a compiler bug"))
    end
    
    local constant = vm.constants[constantIndex + 1] -- Lua arrays are 1-indexed
    
    -- Handle special nil placeholder
    if constant == "__PYLUA_NIL__" then
        constant = nil
    end
    
    VMUtils.push(vm, constant)
end

-- STORE_NAME: Store a value in a named variable
function MemoryOps.storeName(vm: VM, instruction: Instruction)
    local nameIndex = instruction.arg
    if not nameIndex then
        error(VMUtils.createRuntimeError(vm, "BytecodeError", "STORE_NAME instruction missing arg", "This is a compiler bug"))
    end
    
    local name = vm.names[nameIndex + 1] -- Lua arrays are 1-indexed
    local value = VMUtils.pop(vm)
    
    if vm.debug then
        VMUtils.debugLog(vm, string.format("STORE_NAME: nameIndex=%d, name='%s', value=%s (type: %s)", 
            nameIndex, tostring(name), tostring(value), type(value)))
    end
    
    -- Handle nil values specially since Lua tables can't store nil
    if value == nil then
        vm.variables[name] = "__PYLUA_NIL__"
        if vm.debug then
            VMUtils.debugLog(vm, string.format("STORE_NAME: Stored NIL placeholder for '%s'", name))
        end
    else
        vm.variables[name] = value
        if vm.debug then
            VMUtils.debugLog(vm, string.format("STORE_NAME: Stored value for '%s'", name))
        end
    end
    
    -- Debug: Print current variables table
    if vm.debug then
        VMUtils.debugLog(vm, "STORE_NAME: Current variables table:")
        for k, v in pairs(vm.variables) do
            VMUtils.debugLog(vm, string.format("  variables['%s'] = %s (type: %s)", k, tostring(v), type(v)))
        end
    end
end

-- LOAD_NAME: Load a named variable onto the stack
function MemoryOps.loadName(vm: VM, instruction: Instruction)
    local nameIndex = instruction.arg
    if not nameIndex then
        error(VMUtils.createRuntimeError(vm, "BytecodeError", "LOAD_NAME instruction missing arg", "This is a compiler bug"))
    end
    
    if nameIndex < 0 or nameIndex >= #vm.names then
        error(VMUtils.createRuntimeError(vm, "BytecodeError", 
            "Invalid name index " .. tostring(nameIndex) .. " (names table has " .. #vm.names .. " entries)",
            "This is likely a compiler bug"))
    end
    
    local name = vm.names[nameIndex + 1] -- Lua arrays are 1-indexed
    
    VMUtils.debugLog(vm, string.format("LOAD_NAME: nameIndex=%d, name='%s'", nameIndex, tostring(name)))
    
    -- Debug: Print current variables table
    VMUtils.debugLog(vm, "LOAD_NAME: Current variables table:")
    for k, v in pairs(vm.variables) do
        VMUtils.debugLog(vm, string.format("  variables['%s'] = %s (type: %s)", k, tostring(v), type(v)))
    end
    
    local value = vm.variables[name]
    VMUtils.debugLog(vm, string.format("LOAD_NAME: Retrieved value=%s (type: %s) for name='%s'", 
        tostring(value), type(value), name))
    
    local found = false
    
    -- Handle special nil placeholder from variables
    if value == "__PYLUA_NIL__" then
        value = nil
        found = true
        if vm.debug then
            VMUtils.debugLog(vm, string.format("LOAD_NAME: Converted NIL placeholder to nil for '%s'", name))
        end
    elseif value ~= nil then
        found = true
    end
    
    if not found then
        -- If not found in variables, check built-ins
        if vm.debug then
            VMUtils.debugLog(vm, string.format("LOAD_NAME: Variable '%s' not found, checking builtins", name))
        end
        local builtinValue = vm.builtins[name]
        if vm.debug then
            VMUtils.debugLog(vm, string.format("LOAD_NAME: Builtin value=%s (type: %s) for name='%s'", 
                tostring(builtinValue), type(builtinValue), name))
        end
        
        value = builtinValue
        
        -- Handle special nil placeholder from builtins
        if value == "__PYLUA_NIL__" then
            value = nil
            found = true
            if vm.debug then
                VMUtils.debugLog(vm, string.format("LOAD_NAME: Converted builtin NIL placeholder to nil for '%s'", name))
            end
        elseif value ~= nil then
            found = true
        end
    end
    
    if not found then
        local suggestion = "Make sure the variable is defined before using it"
        if name == "range" or name == "print" or name == "len" then
            suggestion = "This is a built-in function - check if the built-ins module is properly loaded"
        end
        error(VMUtils.createRuntimeError(vm, "NameError", "name '" .. name .. "' is not defined", suggestion))
    end
    
    if vm.debug then
        VMUtils.debugLog(vm, "LOAD_NAME " .. name .. " = " .. tostring(value))
        VMUtils.debugLog(vm, string.format("LOAD_NAME: Pushing value=%s onto stack for '%s'", tostring(value), name))
    end
    VMUtils.push(vm, value)
end

-- Stack manipulation operations
function MemoryOps.popTop(vm: VM, instruction: Instruction)
    VMUtils.pop(vm)
end

function MemoryOps.dupTop(vm: VM, instruction: Instruction)
    local value = VMUtils.peek(vm)
    VMUtils.push(vm, value)
end

-- Create opcode handler table
function MemoryOps.createHandlers(): {[string]: (VM, Instruction) -> ()}
    return {
        [Opcodes.LOAD_CONST] = MemoryOps.loadConst,
        [Opcodes.STORE_NAME] = MemoryOps.storeName,
        [Opcodes.LOAD_NAME] = MemoryOps.loadName,
        [Opcodes.POP_TOP] = MemoryOps.popTop,
        [Opcodes.DUP_TOP] = MemoryOps.dupTop,
        
        -- Fast/Global variants (for now, same as name operations)
        [Opcodes.LOAD_FAST] = MemoryOps.loadName,
        [Opcodes.STORE_FAST] = MemoryOps.storeName,
        [Opcodes.LOAD_GLOBAL] = MemoryOps.loadName,
        [Opcodes.STORE_GLOBAL] = MemoryOps.storeName,
    }
end

return MemoryOps
