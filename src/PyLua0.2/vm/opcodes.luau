-- PyLua 0.2 Bytecode Opcodes
-- Defines the instruction set for the PyLua virtual machine

local Opcodes = {
    -- Stack operations
    LOAD_CONST = "LOAD_CONST",     -- Load constant from constants table onto stack
    LOAD_NAME = "LOAD_NAME",       -- Load variable value onto stack
    STORE_NAME = "STORE_NAME",     -- Store top of stack into variable
    
    -- Arithmetic operations
    BINARY_ADD = "BINARY_ADD",     -- Pop two values, add them, push result
    BINARY_SUB = "BINARY_SUB",     -- Pop two values, subtract them, push result
    BINARY_MUL = "BINARY_MUL",     -- Pop two values, multiply them, push result
    BINARY_DIV = "BINARY_DIV",     -- Pop two values, divide them, push result
    BINARY_MOD = "BINARY_MOD",     -- Pop two values, modulo them, push result
    BINARY_POW = "BINARY_POW",     -- Pop two values, power operation, push result
    
    -- Comparison operations
    COMPARE_EQ = "COMPARE_EQ",     -- Pop two values, compare equal, push boolean
    COMPARE_NE = "COMPARE_NE",     -- Pop two values, compare not equal, push boolean
    COMPARE_LT = "COMPARE_LT",     -- Pop two values, compare less than, push boolean
    COMPARE_LE = "COMPARE_LE",     -- Pop two values, compare less equal, push boolean
    COMPARE_GT = "COMPARE_GT",     -- Pop two values, compare greater than, push boolean
    COMPARE_GE = "COMPARE_GE",     -- Pop two values, compare greater equal, push boolean
    
    -- Control flow
    JUMP = "JUMP",                 -- Unconditional jump to instruction
    JUMP_IF_FALSE = "JUMP_IF_FALSE", -- Pop value, jump if false
    JUMP_IF_TRUE = "JUMP_IF_TRUE", -- Pop value, jump if true
    
    -- Function calls
    CALL_FUNCTION = "CALL_FUNCTION", -- Call function with n arguments from stack
    
    -- Loop operations (for Python range, etc.)
    GET_ITER = "GET_ITER",         -- Get iterator from object
    FOR_ITER = "FOR_ITER",         -- Iterate over iterator, jump if exhausted
    
    -- Stack manipulation
    POP_TOP = "POP_TOP",           -- Pop and discard top of stack
    DUP_TOP = "DUP_TOP",           -- Duplicate top of stack
    
    -- Special operations
    BUILD_LIST = "BUILD_LIST",     -- Build list from n stack items
    PRINT_EXPR = "PRINT_EXPR",     -- Print expression result (for interactive mode)
    RETURN_VALUE = "RETURN_VALUE", -- Return value from function/module
}

-- Helper function to check if an opcode is valid
local function isValidOpcode(op)
    for _, validOp in pairs(Opcodes) do
        if op == validOp then
            return true
        end
    end
    return false
end

-- Helper function to get all opcodes as a list
local function getAllOpcodes()
    local opcodeList = {}
    for name, op in pairs(Opcodes) do
        table.insert(opcodeList, {name = name, opcode = op})
    end
    return opcodeList
end

return {
    Opcodes = Opcodes,
    isValidOpcode = isValidOpcode,
    getAllOpcodes = getAllOpcodes,
}