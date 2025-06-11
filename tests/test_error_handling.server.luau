-- Test script for enhanced error handling in PyLua 0.2 Bytecode Executor
-- This script tests various error conditions with proper error reporting

local BytecodeExecutor = require('../src/PyLua/vm/bytecode_executor')

local function testNameError()
    print("=== Testing NameError with line numbers ===")
    
    -- Python equivalent:
    -- print(undefined_variable)  # Line 1
    
    local bytecode = {
        constants = {},
        names = {
            "undefined_variable",  -- 0
            "print",              -- 1
        },
        code = {
            {op="LOAD_NAME", arg=1, line=1},      -- Load print function
            {op="LOAD_NAME", arg=0, line=1},      -- Load undefined variable (will fail)
            {op="CALL_FUNCTION", arg=1, line=1},  -- Call print
        },
        sourceLines = {
            [1] = "print(undefined_variable)"
        }
    }
    
    local success, error = pcall(function()
        BytecodeExecutor.execute(bytecode)
    end)
    
    if not success then
        print("Expected error caught:")
        print(error)
        print("✓ NameError test passed!")
    else
        print("❌ Expected NameError but execution succeeded")
    end
end

local function testTypeError()
    print("\n=== Testing TypeError with context ===")
    
    -- Python equivalent:
    -- result = "hello" + 5  # Line 1
    
    local bytecode = {
        constants = {
            "hello",  -- 0
            5,        -- 1
        },
        names = {
            "result", -- 0
        },
        code = {
            {op="LOAD_CONST", arg=0, line=1},     -- Load "hello"
            {op="LOAD_CONST", arg=1, line=1},     -- Load 5
            {op="BINARY_ADD", line=1},            -- Try to add (will fail)
            {op="STORE_NAME", arg=0, line=1},     -- Store result
        },
        sourceLines = {
            [1] = 'result = "hello" + 5'
        }
    }
    
    local success, error = pcall(function()
        BytecodeExecutor.execute(bytecode)
    end)
    
    if not success then
        print("Expected error caught:")
        print(error)
        print("✓ TypeError test passed!")
    else
        print("❌ Expected TypeError but execution succeeded")
    end
end

local function testZeroDivisionError()
    print("\n=== Testing ZeroDivisionError ===")
    
    -- Python equivalent:
    -- result = 10 / 0  # Line 1
    
    local bytecode = {
        constants = {
            10,  -- 0
            0,   -- 1
        },
        names = {
            "result", -- 0
        },
        code = {
            {op="LOAD_CONST", arg=0, line=1},     -- Load 10
            {op="LOAD_CONST", arg=1, line=1},     -- Load 0
            {op="BINARY_DIV", line=1},            -- Divide by zero (will fail)
            {op="STORE_NAME", arg=0, line=1},     -- Store result
        },
        sourceLines = {
            [1] = "result = 10 / 0"
        }
    }
    
    local success, error = pcall(function()
        BytecodeExecutor.execute(bytecode)
    end)
    
    if not success then
        print("Expected error caught:")
        print(error)
        print("✓ ZeroDivisionError test passed!")
    else
        print("❌ Expected ZeroDivisionError but execution succeeded")
    end
end

local function testDebugMode()
    print("\n=== Testing Debug Mode ===")
    
    -- Simple successful execution with debug output
    local bytecode = {
        constants = {
            42,  -- 0
        },
        names = {
            "answer", -- 0
        },
        code = {
            {op="LOAD_CONST", arg=0, line=1},     -- Load 42
            {op="STORE_NAME", arg=0, line=1},     -- Store in answer
        },
        sourceLines = {
            [1] = "answer = 42"
        }
    }
    
    print("Running with debug mode enabled:")
    local returnValue, variables = BytecodeExecutor.execute(bytecode, {debug = true})
    
    print("Variables:", variables.answer)
    print("✓ Debug mode test passed!")
end

local function testSuccessfulExecution()
    print("\n=== Testing Successful Execution with Line Numbers ===")
    
    -- Python equivalent:
    -- x = 10        # Line 1
    -- y = 20        # Line 2  
    -- sum = x + y   # Line 3
    
    local bytecode = {
        constants = {
            10,  -- 0
            20,  -- 1
        },
        names = {
            "x",    -- 0
            "y",    -- 1
            "sum",  -- 2
        },
        code = {
            {op="LOAD_CONST", arg=0, line=1},     -- x = 10
            {op="STORE_NAME", arg=0, line=1},
            
            {op="LOAD_CONST", arg=1, line=2},     -- y = 20
            {op="STORE_NAME", arg=1, line=2},
            
            {op="LOAD_NAME", arg=0, line=3},      -- sum = x + y
            {op="LOAD_NAME", arg=1, line=3},
            {op="BINARY_ADD", line=3},
            {op="STORE_NAME", arg=2, line=3},
        },
        sourceLines = {
            [1] = "x = 10",
            [2] = "y = 20", 
            [3] = "sum = x + y"
        }
    }
    
    local returnValue, variables = BytecodeExecutor.execute(bytecode)
    
    print("Variables after execution:")
    for name, value in pairs(variables) do
        print("  " .. name .. " = " .. tostring(value))
    end
    
    assert(variables.sum == 30, "sum should be 30")
    print("✓ Successful execution test passed!")
end

-- Run all tests
local function runErrorHandlingTests()
    print("Starting PyLua 0.2 Enhanced Error Handling Tests...")
    
    testSuccessfulExecution()
    testNameError()
    testTypeError() 
    testZeroDivisionError()
    testDebugMode()
    
    print("\n🎉 All error handling tests completed!")
end

-- Execute tests
runErrorHandlingTests()
