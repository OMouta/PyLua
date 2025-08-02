-- PyLua Object Operations
-- Handles object creation, indexing, and attribute operations

local opcodes = require('../opcodes')
local types = require('../../core/types')
local objects = require('../../core/objects')
local VMUtils = require('./vm_utils')

type VM = types.VM
type Instruction = types.Instruction
type Any = types.Any
local Opcodes = opcodes.Opcodes

local ObjectOps = {}

-- BUILD_LIST: Create a Python list object
function ObjectOps.buildList(vm: VM, instruction: Instruction)
    local count = instruction.arg
    if not count then
        error(VMUtils.createRuntimeError(vm, "BytecodeError", "BUILD_LIST instruction missing arg", "This is a compiler bug"))
    end
    
    local items: {Any} = {}
    
    -- Pop items from stack in reverse order
    for i = count, 1, -1 do
        items[i] = VMUtils.pop(vm)
    end

    -- Ensure items is a numerically indexed array
    local array = {}
    for i = 1, count do
        array[i] = items[i]
    end

    if vm.debug then
        VMUtils.debugLog(vm, "BUILD_LIST with " .. count .. " items")
    end
    local list = objects.createList(array)
    VMUtils.push(vm, list)
end

-- BUILD_DICT: Create a Python dictionary object
function ObjectOps.buildDict(vm: VM, instruction: Instruction)
    local count = instruction.arg  -- Number of key-value pairs
    if not count then
        error(VMUtils.createRuntimeError(vm, "BytecodeError", "BUILD_DICT instruction missing arg", "This is a compiler bug"))
    end
    
    local items: {[Any]: Any} = {}
    
    -- Pop key-value pairs from stack
    for i = 1, count do
        local value = VMUtils.pop(vm) 
        local key = VMUtils.pop(vm)   
        items[key] = value
    end
    
    if vm.debug then
        VMUtils.debugLog(vm, "BUILD_DICT with " .. count .. " pairs")
    end
    VMUtils.push(vm, objects.createDict(items))
end

-- BUILD_TUPLE: Create a Python tuple object
function ObjectOps.buildTuple(vm: VM, instruction: Instruction)
    local count = instruction.arg
    if not count then
        error(VMUtils.createRuntimeError(vm, "BytecodeError", "BUILD_TUPLE instruction missing arg", "This is a compiler bug"))
    end
    
    local items: {Any} = {}
    
    -- Pop items from stack in reverse order
    for i = count, 1, -1 do
        items[i] = VMUtils.pop(vm)
    end
    
    if vm.debug then
        VMUtils.debugLog(vm, "BUILD_TUPLE with " .. count .. " items")
    end
    VMUtils.push(vm, objects.createTuple(items))
end

-- BUILD_SET: Create a Python set object
function ObjectOps.buildSet(vm: VM, instruction: Instruction)
    local count = instruction.arg
    if not count then
        error(VMUtils.createRuntimeError(vm, "BytecodeError", "BUILD_SET instruction missing arg", "This is a compiler bug"))
    end
    
    local items: {[Any]: boolean} = {}
    
    -- Pop items and add to set
    for i = 1, count do
        local item_val = VMUtils.pop(vm) 
        items[item_val] = true
    end
    
    if vm.debug then
        VMUtils.debugLog(vm, "BUILD_SET with " .. count .. " items")
    end
    VMUtils.push(vm, objects.createSet(items))
end

-- BINARY_SUBSCR: Get item from object by index/key
function ObjectOps.binarySubscr(vm: VM, instruction: Instruction)
    local index = VMUtils.pop(vm)
    local obj = VMUtils.pop(vm)
    
    if vm.debug then
        VMUtils.debugLog(vm, "BINARY_SUBSCR: " .. tostring(obj) .. "[" .. tostring(index) .. "]")
    end
    
    local success, result = pcall(objects.getItem, obj, index)
    if not success then
        error(VMUtils.createRuntimeError(vm, "IndexError", result, 
            "Check that the index is within bounds and the object supports indexing"))
    end
    
    VMUtils.push(vm, result)
end

-- STORE_SUBSCR: Set item in object by index/key
function ObjectOps.storeSubscr(vm: VM, instruction: Instruction)
    local value = VMUtils.pop(vm)  -- Top of stack: value to assign
    local index = VMUtils.pop(vm)  -- Middle: index/key
    local obj = VMUtils.pop(vm)    -- Bottom: object to assign to
    
    if vm.debug then
        VMUtils.debugLog(vm, "STORE_SUBSCR: " .. tostring(obj) .. "[" .. tostring(index) .. "] = " .. tostring(value))
    end
    
    local success = pcall(objects.setItem, obj, index, value)
    if not success then
        error(VMUtils.createRuntimeError(vm, "TypeError", "Item assignment failed",
            "Check that the object supports item assignment and the index is valid"))
    end
end

-- LOAD_ATTR: Load attribute from object
function ObjectOps.loadAttr(vm: VM, instruction: Instruction)
    if not instruction.arg then
        error(VMUtils.createRuntimeError(vm, "ValueError", "Missing argument for LOAD_ATTR", ""))
    end
    local nameIndex = instruction.arg
    local attrName = vm.names[nameIndex + 1]
    local obj = VMUtils.pop(vm) -- The object whose attribute is being accessed

    if vm.debug then
        VMUtils.debugLog(vm, string.format("[DEBUG LOAD_ATTR] Start. Object type: %s, Attr name: '%s'", type(obj), attrName))
    end
    
    if type(obj) == "table" and obj.__type then -- Ensure obj.__type exists for PyObjects
        if vm.debug then
            VMUtils.debugLog(vm, string.format("[DEBUG LOAD_ATTR] Object is a table. obj.__type: %s", tostring(obj.__type)))
        end

        -- 1. Check for a method in __methods
        if obj.__methods and obj.__methods[attrName] then
            if vm.debug then
                VMUtils.debugLog(vm, string.format("[DEBUG LOAD_ATTR] Found '%s' in obj.__methods of '%s'. Type: %s", attrName, obj.__type, type(obj.__methods[attrName])))
            end
            local method = obj.__methods[attrName]
            if type(method) == "function" then
                local boundMethodClosure = function(...)
                    local actualArgsPassedToClosure = {...} -- Capture all arguments passed to the closure
                    if vm.debug then
                        VMUtils.debugLog(vm, string.format("[DEBUG boundMethodClosure] Called for attr '%s' on obj type '%s'. Self type: %s. Args count: %d", attrName, obj.__type, type(obj), #actualArgsPassedToClosure))
                        if #actualArgsPassedToClosure > 0 then
                            for i, v_arg in ipairs(actualArgsPassedToClosure) do -- Renamed v to v_arg
                                VMUtils.debugLog(vm, string.format("  arg %d: Type: %s, Value: %s", i, type(v_arg), tostring(v_arg)))
                            end
                        end
                    end
                    -- Pass self (obj) and unpacked args to the actual method
                    return method(obj, table.unpack(actualArgsPassedToClosure))
                end
                VMUtils.push(vm, boundMethodClosure)
                if vm.debug then
                    VMUtils.debugLog(vm, string.format("[DEBUG LOAD_ATTR] Pushed boundMethodClosure for method '%s' of '%s'. Returning.", attrName, obj.__type))
                end
                return -- Successfully handled as a method
            else
                -- Attribute found in __methods but is not a function.
                if vm.debug then
                    VMUtils.debugLog(vm, string.format("[DEBUG LOAD_ATTR] Attribute '%s' in __methods of '%s' is not a function (type: %s). Falling through.", attrName, obj.__type, type(method)))
                end
            end
        else
            if vm.debug then
                VMUtils.debugLog(vm, string.format("[DEBUG LOAD_ATTR] Attribute '%s' not found in __methods of '%s'.", attrName, obj.__type))
            end
        end

        -- 2. Check for an item in __dict (relevant for PyDict data, or other object attributes)
        if obj.__dict and obj.__dict[attrName] then
            if vm.debug then
                VMUtils.debugLog(vm, string.format("[DEBUG LOAD_ATTR] Attribute '%s' found in __dict of '%s'. Pushing value. Returning.", attrName, obj.__type))
            end
            VMUtils.push(vm, obj.__dict[attrName])
            return -- Successfully handled as a direct attribute or dict item
        else
            if vm.debug then
                VMUtils.debugLog(vm, string.format("[DEBUG LOAD_ATTR] Attribute '%s' not found in __dict of '%s'.", attrName, obj.__type))
            end
        end

    elseif type(obj) == "table" then -- Generic Lua table, not a PyObject (obj.__type is nil)
        if obj[attrName] ~= nil then
            if vm.debug then
                VMUtils.debugLog(vm, string.format("[DEBUG LOAD_ATTR] Attribute '%s' found in generic Lua table. Pushing value. Returning.", attrName))
            end
            VMUtils.push(vm, obj[attrName])
            return
        end
        if vm.debug then
            VMUtils.debugLog(vm, string.format("[DEBUG LOAD_ATTR] Object is a generic Lua table (no __type), attribute '%s' not found.", attrName))
        end

    else -- Object is not a table
        if vm.debug then
            VMUtils.debugLog(vm, string.format("[DEBUG LOAD_ATTR] Object is not a table (type: %s). Cannot get attribute '%s'.", type(obj), attrName))
        end
    end

    -- If we reach here, the attribute was not found or not handled appropriately
    if vm.debug then
        VMUtils.debugLog(vm, string.format("[DEBUG LOAD_ATTR] Failed to load attribute '%s' for object type %s (value: %s). Erroring.", attrName, tostring(obj and obj.__type or type(obj)), tostring(obj)))
    end
    error(VMUtils.createRuntimeError(vm, "AttributeError",
        "'" .. tostring(obj and obj.__type or type(obj)) .. "' object has no attribute '" .. attrName .. "' or it's not accessible/callable as expected"))
end

-- STORE_ATTR: Store attribute in object
function ObjectOps.storeAttr(vm: VM, instruction: Instruction)
    if not instruction.arg then
        error(VMUtils.createRuntimeError(vm, "ValueError", "Missing argument for STORE_ATTR", ""))
    end
    local nameIndex = instruction.arg
    local attrName = vm.names[nameIndex + 1]
    local obj = VMUtils.pop(vm)
    local value = VMUtils.pop(vm)
    
    if vm.debug then
        VMUtils.debugLog(vm, "STORE_ATTR: " .. tostring(obj) .. "." .. attrName .. " = " .. tostring(value))
    end
    
    if type(obj) == "table" and obj.__dict then
        obj.__dict[attrName] = value
    else
        error(VMUtils.createRuntimeError(vm, "AttributeError",
            "'" .. (obj.__type or type(obj)) .. "' object has no attribute '" .. attrName .. "'",
            "Make sure the object supports attribute assignment"))
    end
end

-- Create opcode handler table
function ObjectOps.createHandlers(): {[string]: (VM, Instruction) -> ()}
    return {
        [Opcodes.BUILD_LIST] = ObjectOps.buildList,
        [Opcodes.BUILD_DICT] = ObjectOps.buildDict,
        [Opcodes.BUILD_TUPLE] = ObjectOps.buildTuple,
        [Opcodes.BUILD_SET] = ObjectOps.buildSet,
        [Opcodes.BINARY_SUBSCR] = ObjectOps.binarySubscr,
        [Opcodes.STORE_SUBSCR] = ObjectOps.storeSubscr,
        [Opcodes.LOAD_ATTR] = ObjectOps.loadAttr,
        [Opcodes.STORE_ATTR] = ObjectOps.storeAttr,
    }
end

return ObjectOps
