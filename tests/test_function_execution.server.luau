-- Test function definition execution in PyLua 0.2
local Python = require('../src/PyLua/python')

-- Test 1: Execute function definition and verify function object creation
print("=== Test 1: Function object creation ===")
local code1 = [[
def greet():
    print("Hello from function!")

print("Function defined")
print("Type of greet:", type(greet))
]]

local bytecode1, error1 = Python.compile(code1)
if error1 then
    print("Compilation error:", error1)
else
    print("Executing function definition...")
    local success, result = pcall(function()
        return Python.runBytecode(bytecode1)
    end)
    
    if success then
        print("Execution successful!")
        print("Result:", result)
    else
        print("Execution error:", result)
    end
end

print()

-- Test 2: Simple function call test
print("=== Test 2: Function call test ===")
local code2 = [[
def say_hello():
    print("Hello from say_hello!")

# Define the function first
print("Function defined")

# Now try to call it
say_hello()
]]

local bytecode2, error2 = Python.compile(code2)
if error2 then
    print("Compilation error:", error2)
else
    print("Executing function call...")
    local success, result = pcall(function()
        return Python.runBytecode(bytecode2)
    end)
    
    if success then
        print("Function call execution successful!")
    else
        print("Function call execution error:", result)
    end
end

print()

-- Test 3: Function with parameters
print("=== Test 3: Function with parameters ===")
local code3 = [[
def greet_person(name):
    print("Hello,", name)

greet_person("Alice")
greet_person("Bob")
]]

local bytecode3, error3 = Python.compile(code3)
if error3 then
    print("Compilation error:", error3)
else
    print("Executing function with parameters...")
    local success, result = pcall(function()
        return Python.runBytecode(bytecode3)
    end)
    
    if success then
        print("Function with parameters execution successful!")
    else
        print("Function with parameters execution error:", result)
    end
end

print()

-- Test 4: Function with return value
print("=== Test 4: Function with return value ===")
local code4 = [[
def add_numbers(x, y):
    result = x + y
    return result

sum_result = add_numbers(5, 3)
print("Sum:", sum_result)
]]

local bytecode4, error4 = Python.compile(code4)
if error4 then
    print("Compilation error:", error4)
else
    print("Executing function with return value...")
    local success, result = pcall(function()
        return Python.runBytecode(bytecode4)
    end)
    
    if success then
        print("Function with return value execution successful!")
    else
        print("Function with return value execution error:", result)
    end
end
