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
    
    -- Merge in any pre-existing globals from runtime
    if options and options.globals then
        for name, value in pairs(options.globals) do
            vm.variables[name] = value
        end
    end
    
    -- Load bytecode into VM
    vm.constants = bytecode.constants or {}
    vm.names = bytecode.names or {}
    vm.code = bytecode.code or {}
    vm.sourceLines = bytecode.sourceLines or {}
    
    -- Get instruction handlers
    local instructionHandlers = createInstructionHandlers()
    
    if vm.debug then
        VMUtils.debugLog(vm, "Starting bytecode execution with " .. #vm.code .. " instructions")
    end
    
    -- Main execution loop
    local originalPC = vm.pc
    while vm.pc <= #vm.code do
        local instruction = vm.code[vm.pc]
        
        if not instruction then
            if vm.debug then
                VMUtils.debugLog(vm, "No instruction at PC " .. vm.pc .. ", ending execution")
            end
            break
        end
        
        if vm.debug then
            VMUtils.debugLog(vm, string.format("PC:%d Executing: %s", vm.pc, instruction.op))
        end
        
        local handler = instructionHandlers[instruction.op]
        if handler then
            originalPC = vm.pc
            local success, errorMessage = pcall(function()
                handler(vm, instruction)
            end)
            if not success then
                if vm.debug then
                    VMUtils.debugLog(vm, "Instruction failed: " .. tostring(errorMessage))
                end
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
    
    if vm.debug then
        VMUtils.debugLog(vm, "Bytecode execution completed")
    end
    
    -- Handle different execution modes
    local mode = (options and options.mode) or "exec"
    local finalReturnValue = vm.returnValue
    
    if mode == "eval" then
        -- In eval mode, if there's no explicit return value, use the top of stack
        if not finalReturnValue and #vm.stack > 0 then
            finalReturnValue = vm.stack[#vm.stack]
            -- Pop the value since we're returning it
            table.remove(vm.stack)
        end
    elseif mode == "exec" then
        -- In exec mode, clear any remaining stack values (like Python exec())
        vm.stack = {}
    end
    
    -- Return execution results
    return {
        variables = vm.variables,
        returnValue = finalReturnValue,
        stack = vm.stack,
        callDepth = vm.callDepth -- Include recursion info for debugging
    }
end

-- Compatibility function for getting variables
function BytecodeExecutor.getVariable(variables, name: string)
    return variables[name]
end

return BytecodeExecutor
