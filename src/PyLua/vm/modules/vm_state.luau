-- PyLua VM State Management
-- Handles VM creation and state operations

local builtins = require('../../core/builtins')
local objects = require('../../core/objects')
local types = require('../../core/types')

type VM = types.VM

local VMState = {}

-- Virtual machine state creation
function VMState.createVM(): VM
    local vm = {
        stack = {},           -- Execution stack
        stackPointer = 0,     -- Current stack position
        pc = 1,              -- Program counter (instruction pointer)
        constants = {},       -- Constants table from bytecode
        names = {},          -- Names table from bytecode
        code = {},           -- Code instructions from bytecode
        variables = {},       -- Runtime variables storage
        builtins = builtins.getBuiltins(),  -- Built-in functions from core module
        returnValue = nil,    -- Last return value
        
        -- Recursion tracking
        callDepth = 0,        -- Current function call depth
        maxCallDepth = 1000,  -- Maximum allowed call depth (recursion limit)
        
        -- Error handling and debugging
        sourceLines = {},     -- Original source code lines for error reporting
        debug = false,        -- Debug mode flag
    }
    
    -- Bind recursion limit functions with VM context
    vm.builtins["getrecursionlimit"] = function()
        return vm.maxCallDepth
    end
    
    vm.builtins["setrecursionlimit"] = function(limit)
        if type(limit) ~= "number" or limit < 1 then
            error("recursion limit must be a positive integer")
        end
        vm.maxCallDepth = limit
        return nil -- Python returns None
    end
    
    -- Create and add sys module to variables
    local sysModule = objects.createSysModule(vm)
    vm.variables["sys"] = sysModule
    
    return vm
end

return VMState
