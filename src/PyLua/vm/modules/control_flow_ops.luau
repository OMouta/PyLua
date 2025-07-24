-- PyLua Control Flow Operations
-- Handles jumps, conditionals, and function calls

local opcodes = require('../opcodes')
local types = require('../../core/types')
local VMUtils = require('./vm_utils')

type VM = types.VM
type Instruction = types.Instruction
type Any = types.Any
local Opcodes = opcodes.Opcodes

local ControlFlowOps = {}

-- JUMP: Unconditional jump
function ControlFlowOps.jump(vm: VM, instruction: Instruction)
    local arg = instruction.arg
    if not arg then
        error(VMUtils.createRuntimeError(vm, "BytecodeError", "JUMP instruction missing arg", "This is a compiler bug"))
    end
    vm.pc = arg + 1 -- Lua arrays are 1-indexed
end

-- JUMP_IF_FALSE: Jump if condition is false
function ControlFlowOps.jumpIfFalse(vm: VM, instruction: Instruction)
    local condition = VMUtils.pop(vm)
    if not condition then
        local arg = instruction.arg
        if not arg then
            error(VMUtils.createRuntimeError(vm, "BytecodeError", "JUMP_IF_FALSE instruction missing arg", "This is a compiler bug"))
        end
        vm.pc = arg + 1 -- Lua arrays are 1-indexed
    end
end

-- JUMP_IF_TRUE: Jump if condition is true
function ControlFlowOps.jumpIfTrue(vm: VM, instruction: Instruction)
    local condition = VMUtils.pop(vm)
    if condition then
        local arg = instruction.arg
        if not arg then
            error(VMUtils.createRuntimeError(vm, "BytecodeError", "JUMP_IF_TRUE instruction missing arg", "This is a compiler bug"))
        end
        vm.pc = arg + 1 -- Lua arrays are 1-indexed
    end
end

-- RETURN_VALUE: Return from function
function ControlFlowOps.returnValue(vm: VM, instruction: Instruction)
    local value = VMUtils.pop(vm)
    VMUtils.debugLog(vm, "RETURN_VALUE: " .. tostring(value))
    vm.returnValue = value
    vm.pc = #vm.code + 1  -- Jump to end of program
end

-- Iterator operations
function ControlFlowOps.getIter(vm: VM, instruction: Instruction)
    local iterable = VMUtils.pop(vm)
    
    -- Create an iterator object for the iterable
    local iterator
    if type(iterable) == "table" then
        if iterable.__type == "list" then
            -- Python list object
            iterator = {
                type = "list",
                data = iterable.__value,
                index = 1,
                length = #iterable.__value
            }
        elseif iterable.__type == "tuple" then
            -- Python tuple object
            iterator = {
                type = "list",
                data = iterable.__value,
                index = 1,
                length = #iterable.__value
            }
        elseif iterable.__type == "set" then
            -- Python set object - convert to array for iteration
            local setArray = {}
            for value, _ in pairs(iterable.__value) do
                table.insert(setArray, value)
            end
            iterator = {
                type = "list",
                data = setArray,
                index = 1,
                length = #setArray
            }
        elseif iterable.__type == "dict" then
            -- Python dict object - iterate over keys
            local keyArray = {}
            for key, _ in pairs(iterable.__value) do
                table.insert(keyArray, key)
            end
            iterator = {
                type = "list",
                data = keyArray,
                index = 1,
                length = #keyArray
            }
        else
            -- Generic Lua table (for range() etc)
            iterator = {
                type = "list",
                data = iterable,
                index = 1,
                length = #iterable
            }
        end
    else
        error(VMUtils.createRuntimeError(vm, "TypeError", "Object is not iterable: " .. type(iterable),
            "Make sure the object supports iteration"))
    end
    
    VMUtils.push(vm, iterator)
end

function ControlFlowOps.forIter(vm: VM, instruction: Instruction)
    local iterator = VMUtils.peek(vm) -- Don't pop yet, we need it for the next iteration
    
    if iterator.type == "list" then
        if iterator.index <= iterator.length then
            -- Push the current value onto the stack
            VMUtils.push(vm, iterator.data[iterator.index])
            iterator.index = iterator.index + 1
            -- Continue to next instruction (don't jump)
        else
            -- Iterator exhausted, pop it and jump to end of loop
            VMUtils.pop(vm) -- Remove the iterator
            local arg = instruction.arg
            if not arg then
                error(VMUtils.createRuntimeError(vm, "BytecodeError", "FOR_ITER instruction missing arg", "This is a compiler bug"))
            end
            vm.pc = arg + 1 -- Jump to instruction after loop
        end
    elseif iterator.type == "sequence" then
        if iterator.index <= iterator.length then
            -- Push the current value onto the stack
            VMUtils.push(vm, iterator.data[iterator.index])
            iterator.index = iterator.index + 1
            -- Continue to next instruction (don't jump)
        else
            -- Iterator exhausted, pop it and jump to end of loop
            VMUtils.pop(vm) -- Remove the iterator
            local arg = instruction.arg
            if not arg then
                error(VMUtils.createRuntimeError(vm, "BytecodeError", "FOR_ITER instruction missing arg", "This is a compiler bug"))
            end
            vm.pc = arg + 1 -- Jump to instruction after loop
        end
    else
        error(VMUtils.createRuntimeError(vm, "RuntimeError", 
            "Unknown iterator type: " .. tostring(iterator.type),
            "This is likely a VM bug"))
    end
end

-- Create opcode handler table
function ControlFlowOps.createHandlers(): {[string]: (VM, Instruction) -> ()}
    return {
        [Opcodes.JUMP] = ControlFlowOps.jump,
        [Opcodes.JUMP_IF_FALSE] = ControlFlowOps.jumpIfFalse,
        [Opcodes.JUMP_IF_TRUE] = ControlFlowOps.jumpIfTrue,
        [Opcodes.RETURN_VALUE] = ControlFlowOps.returnValue,
        [Opcodes.GET_ITER] = ControlFlowOps.getIter,
        [Opcodes.FOR_ITER] = ControlFlowOps.forIter,
    }
end

return ControlFlowOps
