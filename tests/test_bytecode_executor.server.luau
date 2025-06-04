-- Test script for PyLua 0.2 Bytecode Executor
-- This script tests the bytecode executor with hand-crafted bytecode

local BytecodeExecutor = require('../src/PyLua0.2/vm/bytecode_executor')

local function testBasicAssignment()
    print("=== Testing Basic Assignment ===")
    
    -- Python equivalent:
    -- message = "Hello from Python!"
    -- score = 85
    
    local bytecode = {
        constants = {
            "Hello from Python!",  -- 0
            85,                    -- 1
        },
        names = {
            "message",             -- 0
            "score",               -- 1
        },
        code = {
            {op="LOAD_CONST", arg=0},   -- Load "Hello from Python!"
            {op="STORE_NAME", arg=0},   -- Store in 'message'
            {op="LOAD_CONST", arg=1},   -- Load 85
            {op="STORE_NAME", arg=1},   -- Store in 'score'
        }
    }
    
    local returnValue, variables = BytecodeExecutor.execute(bytecode)
    
    print("Variables after execution:")
    for name, value in pairs(variables) do
        print("  " .. name .. " = " .. tostring(value))
    end
    
    -- Verify results
    assert(variables.message == "Hello from Python!", "message variable incorrect")
    assert(variables.score == 85, "score variable incorrect")
    print("✓ Basic assignment test passed!")
end

local function testArithmetic()
    print("\n=== Testing Arithmetic Operations ===")
    
    -- Python equivalent:
    -- a = 10
    -- b = 5
    -- sum_result = a + b
    -- diff_result = a - b
    
    local bytecode = {
        constants = {
            10,  -- 0
            5,   -- 1
        },
        names = {
            "a",           -- 0
            "b",           -- 1
            "sum_result",  -- 2
            "diff_result", -- 3
        },
        code = {
            -- a = 10
            {op="LOAD_CONST", arg=0},
            {op="STORE_NAME", arg=0},
            
            -- b = 5
            {op="LOAD_CONST", arg=1},
            {op="STORE_NAME", arg=1},
            
            -- sum_result = a + b
            {op="LOAD_NAME", arg=0},    -- Load a
            {op="LOAD_NAME", arg=1},    -- Load b
            {op="BINARY_ADD"},          -- a + b
            {op="STORE_NAME", arg=2},   -- Store in sum_result
            
            -- diff_result = a - b
            {op="LOAD_NAME", arg=0},    -- Load a
            {op="LOAD_NAME", arg=1},    -- Load b
            {op="BINARY_SUB"},          -- a - b
            {op="STORE_NAME", arg=3},   -- Store in diff_result
        }
    }
    
    local returnValue, variables = BytecodeExecutor.execute(bytecode)
    
    print("Variables after execution:")
    for name, value in pairs(variables) do
        print("  " .. name .. " = " .. tostring(value))
    end
    
    -- Verify results
    assert(variables.a == 10, "a variable incorrect")
    assert(variables.b == 5, "b variable incorrect")
    assert(variables.sum_result == 15, "sum_result incorrect")
    assert(variables.diff_result == 5, "diff_result incorrect")
    print("✓ Arithmetic test passed!")
end

local function testComparison()
    print("\n=== Testing Comparison Operations ===")
    
    -- Python equivalent:
    -- score = 85
    -- passing = score >= 80
    
    local bytecode = {
        constants = {
            85,  -- 0
            80,  -- 1
        },
        names = {
            "score",   -- 0
            "passing", -- 1
        },
        code = {
            -- score = 85
            {op="LOAD_CONST", arg=0},
            {op="STORE_NAME", arg=0},
            
            -- passing = score >= 80
            {op="LOAD_NAME", arg=0},    -- Load score
            {op="LOAD_CONST", arg=1},   -- Load 80
            {op="COMPARE_GE"},          -- score >= 80
            {op="STORE_NAME", arg=1},   -- Store in passing
        }
    }
    
    local returnValue, variables = BytecodeExecutor.execute(bytecode)
    
    print("Variables after execution:")
    for name, value in pairs(variables) do
        print("  " .. name .. " = " .. tostring(value))
    end
    
    -- Verify results
    assert(variables.score == 85, "score variable incorrect")
    assert(variables.passing == true, "passing variable should be true")
    print("✓ Comparison test passed!")
end

local function testForLoop()
    print("\n=== Testing Real For Loop with Jumps ===")
    
    -- Python equivalent:
    -- sum_i = 0
    -- for i in range(5):
    --     sum_i = sum_i + i
    
    local bytecode = {
        constants = {
            0,          -- 0 (initial sum_i)
            5,          -- 1 (range limit)
        },
        names = {
            "sum_i",    -- 0
            "range",    -- 1
            "i",        -- 2
        },
        code = {
            -- sum_i = 0
            {op="LOAD_CONST", arg=0},      -- instruction 1
            {op="STORE_NAME", arg=0},      -- instruction 2
            
            -- range(5)
            {op="LOAD_NAME", arg=1},       -- instruction 3: load 'range'
            {op="LOAD_CONST", arg=1},      -- instruction 4: load 5
            {op="CALL_FUNCTION", arg=1},   -- instruction 5: call range(5)
            {op="GET_ITER"},               -- instruction 6: get iterator
            
            -- Loop start (instruction 7)
            {op="FOR_ITER", arg=14},       -- instruction 7: jump to instruction 15 if exhausted
            {op="STORE_NAME", arg=2},      -- instruction 8: store current value in 'i'
            
            -- sum_i = sum_i + i
            {op="LOAD_NAME", arg=0},       -- instruction 9: load sum_i
            {op="LOAD_NAME", arg=2},       -- instruction 10: load i
            {op="BINARY_ADD"},             -- instruction 11: sum_i + i
            {op="STORE_NAME", arg=0},      -- instruction 12: store back to sum_i
            
            {op="JUMP", arg=6},            -- instruction 13: jump back to FOR_ITER (instruction 7, 0-indexed = 6)
            
            -- End of loop (instruction 14)
            -- Program continues here after loop
        }
    }
    
    local returnValue, variables = BytecodeExecutor.execute(bytecode)
    
    print("Variables after execution:")
    for name, value in pairs(variables) do
        print("  " .. name .. " = " .. tostring(value))
    end
    
    -- Verify results (should be 0+1+2+3+4 = 10, like the original test)
    assert(variables.sum_i == 10, "sum_i should be 10, got " .. tostring(variables.sum_i))
    print("✓ Real for loop test passed!")
end

-- Run all tests
local function runAllTests()
    print("Starting PyLua 0.2 Bytecode Executor Tests...")
    
    local success, error = pcall(testBasicAssignment)
    if not success then
        print("❌ Basic assignment test failed: " .. tostring(error))
        return
    end
    
    success, error = pcall(testArithmetic)
    if not success then
        print("❌ Arithmetic test failed: " .. tostring(error))
        return
    end
    
    success, error = pcall(testComparison)
    if not success then
        print("❌ Comparison test failed: " .. tostring(error))
        return
    end
    
    success, error = pcall(testForLoop)
    if not success then
        print("❌ For loop test failed: " .. tostring(error))
        return
    end
    
    print("\n🎉 All tests passed! Bytecode executor is working correctly.")
end

-- Execute tests
runAllTests()
