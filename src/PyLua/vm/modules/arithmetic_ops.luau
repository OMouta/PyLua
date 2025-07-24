-- PyLua Arithmetic Operations
-- Handles arithmetic and comparison operations

local opcodes = require('../opcodes')
local types = require('../../core/types')
local VMUtils = require('./vm_utils')

type VM = types.VM
type Instruction = types.Instruction
local Opcodes = opcodes.Opcodes

local ArithmeticOps = {}

-- Arithmetic operations with type checking
function ArithmeticOps.binaryAdd(vm: VM, instruction: Instruction)
    local b = VMUtils.pop(vm)
    local a = VMUtils.pop(vm)
    
    if type(a) == "number" and type(b) == "number" then
        VMUtils.push(vm, a + b)
    elseif type(a) == "string" and type(b) == "string" then
        VMUtils.push(vm, a .. b) -- String concatenation
    else
        error(VMUtils.createRuntimeError(vm, "TypeError", 
            "unsupported operand type(s) for +: '" .. type(a) .. "' and '" .. type(b) .. "'",
            "Addition requires two numbers or two strings"))
    end
end

function ArithmeticOps.binarySub(vm: VM, instruction: Instruction)
    local b = VMUtils.pop(vm)
    local a = VMUtils.pop(vm)
    
    if type(a) ~= "number" or type(b) ~= "number" then
        error(VMUtils.createRuntimeError(vm, "TypeError", 
            "unsupported operand type(s) for -: '" .. type(a) .. "' and '" .. type(b) .. "'",
            "Subtraction requires two numbers"))
    end
    
    VMUtils.push(vm, a - b)
end

function ArithmeticOps.binaryMul(vm: VM, instruction: Instruction)
    local b = VMUtils.pop(vm)
    local a = VMUtils.pop(vm)
    
    if type(a) ~= "number" or type(b) ~= "number" then
        error(VMUtils.createRuntimeError(vm, "TypeError", 
            "unsupported operand type(s) for *: '" .. type(a) .. "' and '" .. type(b) .. "'",
            "Multiplication requires two numbers"))
    end
    
    VMUtils.push(vm, a * b)
end

function ArithmeticOps.binaryDiv(vm: VM, instruction: Instruction)
    local b = VMUtils.pop(vm)
    local a = VMUtils.pop(vm)
    
    if type(a) ~= "number" or type(b) ~= "number" then
        error(VMUtils.createRuntimeError(vm, "TypeError", 
            "unsupported operand type(s) for /: '" .. type(a) .. "' and '" .. type(b) .. "'",
            "Division requires two numbers"))
    end
    
    if b == 0 then
        error(VMUtils.createRuntimeError(vm, "ZeroDivisionError", "division by zero",
            "Check that the divisor is not zero before performing division"))
    end
    
    VMUtils.push(vm, a / b)
end

function ArithmeticOps.binaryMod(vm: VM, instruction: Instruction)
    local b = VMUtils.pop(vm)
    local a = VMUtils.pop(vm)
    
    if type(a) ~= "number" or type(b) ~= "number" then
        error(VMUtils.createRuntimeError(vm, "TypeError", 
            "unsupported operand type(s) for %: '" .. type(a) .. "' and '" .. type(b) .. "'",
            "Modulo requires two numbers"))
    end
    
    VMUtils.push(vm, a % b)
end

function ArithmeticOps.binaryPow(vm: VM, instruction: Instruction)
    local b = VMUtils.pop(vm)
    local a = VMUtils.pop(vm)
    
    if type(a) ~= "number" or type(b) ~= "number" then
        error(VMUtils.createRuntimeError(vm, "TypeError", 
            "unsupported operand type(s) for **: '" .. type(a) .. "' and '" .. type(b) .. "'",
            "Exponentiation requires two numbers"))
    end
    
    VMUtils.push(vm, a ^ b)
end

-- Comparison operations
function ArithmeticOps.compareEq(vm: VM, instruction: Instruction)
    local b = VMUtils.pop(vm)
    local a = VMUtils.pop(vm)
    VMUtils.push(vm, a == b)
end

function ArithmeticOps.compareNe(vm: VM, instruction: Instruction)
    local b = VMUtils.pop(vm)
    local a = VMUtils.pop(vm)
    VMUtils.push(vm, a ~= b)
end

function ArithmeticOps.compareLt(vm: VM, instruction: Instruction)
    local b = VMUtils.pop(vm)
    local a = VMUtils.pop(vm)
    
    if type(a) ~= type(b) then
        error(VMUtils.createRuntimeError(vm, "TypeError", 
            "unsupported operand type(s) for <: '" .. type(a) .. "' and '" .. type(b) .. "'",
            "Comparison requires compatible types"))
    end
    
    VMUtils.push(vm, a < b)
end

function ArithmeticOps.compareLe(vm: VM, instruction: Instruction)
    local b = VMUtils.pop(vm)
    local a = VMUtils.pop(vm)
    
    if type(a) ~= type(b) then
        error(VMUtils.createRuntimeError(vm, "TypeError", 
            "unsupported operand type(s) for <=: '" .. type(a) .. "' and '" .. type(b) .. "'",
            "Comparison requires compatible types"))
    end
    
    VMUtils.push(vm, a <= b)
end

function ArithmeticOps.compareGt(vm: VM, instruction: Instruction)
    local b = VMUtils.pop(vm)
    local a = VMUtils.pop(vm)
    
    if type(a) ~= type(b) then
        error(VMUtils.createRuntimeError(vm, "TypeError", 
            "unsupported operand type(s) for >: '" .. type(a) .. "' and '" .. type(b) .. "'",
            "Comparison requires compatible types"))
    end
    
    VMUtils.push(vm, a > b)
end

function ArithmeticOps.compareGe(vm: VM, instruction: Instruction)
    local b = VMUtils.pop(vm)
    local a = VMUtils.pop(vm)
    
    if type(a) ~= type(b) then
        error(VMUtils.createRuntimeError(vm, "TypeError", 
            "unsupported operand type(s) for >=: '" .. type(a) .. "' and '" .. type(b) .. "'",
            "Comparison requires compatible types"))
    end
    
    VMUtils.push(vm, a >= b)
end

-- Type checking operation
function ArithmeticOps.getType(vm: VM, instruction: Instruction)
    local obj = VMUtils.pop(vm)
    
    if type(obj) == "table" and obj.__type then
        VMUtils.push(vm, obj.__type)
    else
        -- Convert Lua types to Python type names
        local luaType = type(obj)
        if luaType == "number" then
            if obj % 1 == 0 then
                VMUtils.push(vm, "int")
            else
                VMUtils.push(vm, "float")
            end
        elseif luaType == "string" then
            VMUtils.push(vm, "str")
        elseif luaType == "boolean" then
            VMUtils.push(vm, "bool")
        elseif luaType == "nil" then
            VMUtils.push(vm, "NoneType")
        else
            VMUtils.push(vm, luaType)
        end
    end
end

-- Create opcode handler table
function ArithmeticOps.createHandlers(): {[string]: (VM, Instruction) -> ()}
    return {
        [Opcodes.BINARY_ADD] = ArithmeticOps.binaryAdd,
        [Opcodes.BINARY_SUB] = ArithmeticOps.binarySub,
        [Opcodes.BINARY_MUL] = ArithmeticOps.binaryMul,
        [Opcodes.BINARY_DIV] = ArithmeticOps.binaryDiv,
        [Opcodes.BINARY_MOD] = ArithmeticOps.binaryMod,
        [Opcodes.BINARY_POW] = ArithmeticOps.binaryPow,
        [Opcodes.COMPARE_EQ] = ArithmeticOps.compareEq,
        [Opcodes.COMPARE_NE] = ArithmeticOps.compareNe,
        [Opcodes.COMPARE_LT] = ArithmeticOps.compareLt,
        [Opcodes.COMPARE_LE] = ArithmeticOps.compareLe,
        [Opcodes.COMPARE_GT] = ArithmeticOps.compareGt,
        [Opcodes.COMPARE_GE] = ArithmeticOps.compareGe,
        [Opcodes.GET_TYPE] = ArithmeticOps.getType,
    }
end

return ArithmeticOps
