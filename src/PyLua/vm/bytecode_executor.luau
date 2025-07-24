-- PyLua Bytecode Executor (New Modular Version)
-- Main orchestrator for the refactored bytecode execution system

local VMState = require('./modules/vm_state')
local VMUtils = require('./modules/vm_utils')
local MemoryOps = require('./modules/memory_ops')
local ArithmeticOps = require('./modules/arithmetic_ops')
local ControlFlowOps = require('./modules/control_flow_ops')
local FunctionOps = require('./modules/function_ops')
local ObjectOps = require('./modules/object_ops')

local types = require('../core/types')
type VM = types.VM
type Bytecode = types.Bytecode
type ExecutionOptions = types.ExecutionOptions

local BytecodeExecutor = {}

-- Initialize instruction handlers
local function createInstructionHandlers()
    local handlers = {}
    
    -- Combine all module handlers
    local allHandlers = {
        MemoryOps.createHandlers(),
        ArithmeticOps.createHandlers(),
        ControlFlowOps.createHandlers(),
        FunctionOps.createHandlers(),
        ObjectOps.createHandlers(),
    }
    
    -- Merge all handler tables
    for _, handlerTable in ipairs(allHandlers) do
        for opcode, handler in pairs(handlerTable) do
            handlers[opcode] = handler
        end
    end
    
    return handlers
end

-- Execute bytecode with the modular VM
function BytecodeExecutor.execute(bytecode: Bytecode, options: ExecutionOptions?): any
    options = options or {}
    
    -- Create VM with recursion tracking
    local vm = VMState.createVM()
    vm.debug = (options and options.debug) or false
    
    -- Load bytecode into VM
    vm.constants = bytecode.constants or {}
    vm.names = bytecode.names or {}
    vm.code = bytecode.code or {}
    vm.sourceLines = bytecode.sourceLines or {}
    
    -- Get instruction handlers
    local instructionHandlers = createInstructionHandlers()
    
    VMUtils.debugLog(vm, "Starting bytecode execution with " .. #vm.code .. " instructions")
    
    -- Main execution loop
    local originalPC = vm.pc
    while vm.pc <= #vm.code do
        local instruction = vm.code[vm.pc]
        
        if not instruction then
            VMUtils.debugLog(vm, "No instruction at PC " .. vm.pc .. ", ending execution")
            break
        end
        
        VMUtils.debugLog(vm, string.format("PC:%d Executing: %s", vm.pc, instruction.op))
        
        local handler = instructionHandlers[instruction.op]
        if handler then
            originalPC = vm.pc
            local success, errorMessage = pcall(function()
                handler(vm, instruction)
            end)
            if not success then
                VMUtils.debugLog(vm, "Instruction failed: " .. tostring(errorMessage))
                error(errorMessage) -- Re-raise the error
            end
        else
            error(VMUtils.createRuntimeError(vm, "BytecodeError", 
                "Unknown opcode: " .. tostring(instruction.op),
                "This is likely a compiler bug or corrupted bytecode"))
        end
        
        -- Advance to next instruction (unless handler modified PC)
        if vm.pc == originalPC then
            vm.pc = vm.pc + 1
        end
    end
    
    VMUtils.debugLog(vm, "Bytecode execution completed")
    
    -- Return execution results
    return {
        variables = vm.variables,
        returnValue = vm.returnValue,
        stack = vm.stack,
        callDepth = vm.callDepth -- Include recursion info for debugging
    }
end

-- Compatibility function for getting variables
function BytecodeExecutor.getVariable(variables, name: string)
    return variables[name]
end

return BytecodeExecutor
