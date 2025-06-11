-- Test function definitions in PyLua 0.2
local Python = require('../src/PyLua/python')

-- Test 1: Simple function definition
print("=== Test 1: Simple function definition ===")
local code1 = [[
def greet():
    print("Hello, World!")

print("Function defined")
]]

local bytecode1, error1 = Python.compile(code1)
if error1 then
    print("Compilation error:", error1)
else
    print("Bytecode generated successfully")
    print("Constants:", bytecode1.constants)
    print("Names:", bytecode1.names)
    print("Code instructions:")
    for i, instruction in ipairs(bytecode1.code) do
        print("  " .. i .. ": " .. instruction.op .. " arg=" .. tostring(instruction.arg))
    end
end

print()

-- Test 2: Function with parameters
print("=== Test 2: Function with parameters ===")
local code2 = [[
def add(x, y):
    result = x + y
    return result
]]

local bytecode2, error2 = Python.compile(code2)
if error2 then
    print("Compilation error:", error2)
else
    print("Bytecode generated successfully")
    print("Function bytecode structure created")
end

print()

-- Test 3: Function with return statement
print("=== Test 3: Function with return statement ===")
local code3 = [[
def calculate(a, b):
    sum_val = a + b
    product = a * b
    return product
]]

local bytecode3, error3 = Python.compile(code3)
if error3 then
    print("Compilation error:", error3)
else
    print("Bytecode generated successfully")
    print("Function with return compiled")
end

print()

-- Test 4: Function with no parameters and return
print("=== Test 4: Function with no parameters and return ===")
local code4 = [[
def get_message():
    message = "Hello from function!"
    return message
]]

local bytecode4, error4 = Python.compile(code4)
if error4 then
    print("Compilation error:", error4)
else
    print("Bytecode generated successfully")
    print("Function compilation complete")
end
