-- Test Recursion Limit with Pythonic Sys Module
-- Tests recursion limit using the proper Python sys module syntax

local python = require('../src/PyLua')

print("=== Testing Recursion Limit ===")

-- Test 1: Test that recursion limit prevents infinite recursion
print("\n1. Testing infinite recursion prevention...")

local infiniteRecursionCode = [[
def endless_loop():
    endless_loop()

endless_loop()
]]

local success, result = pcall(function()
    return python:execute(infiniteRecursionCode)
end)

if success then
    print("❌ ERROR: Infinite recursion should have been caught!")
else
    local errorStr = tostring(result)
    if string.find(errorStr, "RecursionError") and string.find(errorStr, "maximum recursion depth exceeded") then
        print("✅ SUCCESS: Recursion limit correctly prevented infinite recursion")
        print("   Error:", errorStr:match("RecursionError: ([^%c]+)"))
    else
        print("❌ ERROR: Wrong error type. Expected RecursionError, got:", errorStr)
    end
end

-- Test 2: Test sys.getrecursionlimit() and sys.setrecursionlimit()
print("\n2. Testing sys module recursion limit functions...")

local sysRecursionLimitCode = [[
# Test getting current recursion limit via sys module
current_limit = sys.getrecursionlimit()
print("Current recursion limit:", current_limit)

# Test setting recursion limit to a smaller value
sys.setrecursionlimit(100)
new_limit = sys.getrecursionlimit()
print("New recursion limit:", new_limit)
]]

local success2, result2 = pcall(function()
    return python:execute(sysRecursionLimitCode)
end)

if success2 then
    print("✅ SUCCESS: Sys module recursion limit functions work correctly")
else
    print("❌ ERROR:", result2)
end

-- Test 3: Test that reduced recursion limit is enforced
print("\n3. Testing reduced recursion limit enforcement...")

local reducedLimitCode = [[
# Set a very low recursion limit using sys module
sys.setrecursionlimit(5)

def recursive_function(n):
    if n > 0:
        return recursive_function(n - 1)
    return n

# This should fail with only 5 calls allowed
recursive_function(10)
]]

local success3, result3 = pcall(function()
    return python:execute(reducedLimitCode)
end)

if success3 then
    print("❌ ERROR: Reduced recursion limit should have been enforced!")
else
    local errorStr = tostring(result3)
    if string.find(errorStr, "RecursionError") then
        print("✅ SUCCESS: Reduced recursion limit correctly enforced")
        print("   Error:", errorStr:match("RecursionError: ([^%c]+)"))
    else
        print("❌ ERROR: Wrong error type. Expected RecursionError, got:", errorStr)
    end
end

-- Test 4: Test valid recursion within limits
print("\n4. Testing valid recursion within limits...")

local validRecursionCode = [[
sys.setrecursionlimit(1000)  # Reset to default

def factorial(n):
    if n <= 1:
        return 1
    return n * factorial(n - 1)

result = factorial(5)
print("Factorial of 5:", result)
print("Current recursion limit:", sys.getrecursionlimit())
]]

local success4, result4 = pcall(function()
    return python:execute(validRecursionCode)
end)

if success4 then
    print("✅ SUCCESS: Valid recursion works correctly")
else
    print("❌ ERROR:", result4)
end

-- Test 5: Test sys module attributes
print("\n5. Testing sys module information...")

local sysInfoCode = [[
print("Python version:", sys.version)
print("Platform:", sys.platform)
print("Max size:", sys.maxsize)
]]

local success5, result5 = pcall(function()
    return python:execute(sysInfoCode)
end)

if success5 then
    print("✅ SUCCESS: Sys module information accessible")
else
    print("❌ ERROR:", result5)
end

print("\n=== Recursion Limit Tests Complete ===")