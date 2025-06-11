-- Complete function features test for PyLua 0.2
local Python = require('../src/PyLua/python')

print("=== PyLua 0.2 Function Features Test ===")

-- Test comprehensive function functionality
local code = [[
# Test 1: Basic function definition and call
def hello():
    print("Hello from function!")

hello()

# Test 2: Function with parameters
def greet(name, greeting):
    print(greeting + ", " + name + "!")

greet("Alice", "Hello")
greet("Bob", "Hi")

# Test 3: Function with return value
def add(x, y):
    return x + y

def multiply(a, b):
    result = a * b
    return result

sum_result = add(10, 5)
product = multiply(3, 4)

print("Sum:", sum_result)
print("Product:", product)

# Test 4: Function calling other functions
def calculate_area(length, width):
    return multiply(length, width)

area = calculate_area(6, 8)
print("Area:", area)

# Test 5: Functions with local variables
def test_locals():
    local_var = "I'm local!"
    print("Local variable:", local_var)
    return local_var

result = test_locals()
print("Returned:", result)

# Test 6: Type checking
print("Type of hello:", type(hello))
print("Type of add:", type(add))
print("Type of sum_result:", type(sum_result))

print("All function tests completed!")
]]

local bytecode, error = Python.compile(code)
if error then
    print("Compilation error:", error)
else
    print("Compilation successful! Executing...")
    local success, result = pcall(function()
        return Python.runBytecode(bytecode)
    end)
    
    if success then
        print("Function features working correctly!")
    else
        print("Execution error:", result)
    end
end
