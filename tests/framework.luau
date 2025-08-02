--!strict
-- PyLua Test Framework
-- Simple testing utilities for PyLua development

local TestFramework = {}

-- Test result tracking
local totalTests = 0
local passedTests = 0
local failedTests = 0

-- Test suite definition
export type TestSuite = {
    name: string,
    tests: {TestCase},
}

export type TestCase = {
    name: string,
    test: () -> (),
}

-- Assert functions
function TestFramework.assert(condition: boolean, message: string?)
    totalTests = totalTests + 1
    
    if condition then
        passedTests = passedTests + 1
        print("✓ " .. (message or "Assertion passed"))
    else
        failedTests = failedTests + 1
        local msg = message or "Assertion failed"
        print("✗ " .. msg)
        error(msg, 2)
    end
end

function TestFramework.assertEqual(actual: any, expected: any, message: string?)
    local msg = message or ("Expected " .. tostring(expected) .. " but got " .. tostring(actual))
    TestFramework.assert(actual == expected, msg)
end

function TestFramework.assertNotEqual(actual: any, expected: any, message: string?)
    local msg = message or ("Expected not " .. tostring(expected) .. " but got " .. tostring(actual))
    TestFramework.assert(actual ~= expected, msg)
end

function TestFramework.assertType(value: any, expectedType: string, message: string?)
    local actualType = type(value)
    local msg = message or ("Expected type " .. expectedType .. " but got " .. actualType)
    TestFramework.assert(actualType == expectedType, msg)
end

function TestFramework.assertTrue(condition: boolean, message: string?)
    local msg = message or "Expected true but got false"
    TestFramework.assert(condition == true, msg)
end

function TestFramework.assertFalse(condition: boolean, message: string?)
    local msg = message or "Expected false but got true"
    TestFramework.assert(condition == false, msg)
end

function TestFramework.assertError(func: () -> any, message: string?)
    totalTests = totalTests + 1
    
    local success, err = pcall(func)
    if success then
        failedTests = failedTests + 1
        local msg = message or "Expected error but none occurred"
        print("✗ " .. msg)
        error(msg, 2)
    else
        passedTests = passedTests + 1
        print("✓ " .. (message or "Expected error occurred: " .. tostring(err)))
    end
end

-- Run a test suite
function TestFramework.runSuite(suite: TestSuite)
    print("\n=== Running Test Suite: " .. suite.name .. " ===")
    
    for _, testCase in ipairs(suite.tests) do
        print("\nRunning test: " .. testCase.name)
        
        local success, err = pcall(function()
            testCase.test()
        end)
        
        if not success then
            print("✗ Test failed with error: " .. tostring(err))
            failedTests = failedTests + 1
        end
    end
end

-- Print test results summary
function TestFramework.printSummary()
    print("\n=== Test Summary ===")
    print("Total tests: " .. totalTests)
    print("Passed: " .. passedTests)
    print("Failed: " .. failedTests)
    
    if failedTests == 0 then
        print("🎉 All tests passed!")
    else
        print("❌ " .. failedTests .. " tests failed")
    end
    
    return failedTests == 0
end

-- Reset test counters
function TestFramework.reset()
    totalTests = 0
    passedTests = 0
    failedTests = 0
end

return TestFramework
