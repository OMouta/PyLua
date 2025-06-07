local python = require('../src/PyLua0.2/python')

-- Test 1: Simple if statement
print("=== Test 1: Simple if statement ===")
local code1 = [[
x = 5
if x > 3:
    print("x is greater than 3")
    print("Inside if block")
print("After if statement")
]]

local bytecode1, error1 = python.compile(code1)
if error1 then
    print("Compilation error:", error1)
else
    print("Bytecode generated successfully")
    print("Executing...")
    local success, result = pcall(python.runBytecode, bytecode1)
    if success then
        print("Execution completed")
    else
        print("Execution error:", result)
    end
end

print()

-- Test 2: if/else statement
print("=== Test 2: if/else statement ===")
local code2 = [[
x = 2
if x > 5:
    print("x is greater than 5")
else:
    print("x is not greater than 5")
    print("x is:", x)
print("After if/else statement")
]]

local bytecode2, error2 = python.compile(code2)
if error2 then
    print("Compilation error:", error2)
else
    print("Bytecode generated successfully")
    print("Executing...")
    local success, result = pcall(python.runBytecode, bytecode2)
    if success then
        print("Execution completed")
    else
        print("Execution error:", result)
    end
end

print()

-- Test 3: if/elif/else statement
print("=== Test 3: if/elif/else statement ===")
local code3 = [[
score = 85
if score >= 90:
    print("Grade: A")
elif score >= 80:
    print("Grade: B")
    print("Good job!")
elif score >= 70:
    print("Grade: C")
else:
    print("Grade: F")
    print("Need improvement")
print("Final score:", score)
]]

local bytecode3, error3 = python.compile(code3)
if error3 then
    print("Compilation error:", error3)
else
    print("Bytecode generated successfully")
    print("Executing...")
    local success, result = pcall(python.runBytecode, bytecode3)
    if success then
        print("Execution completed")
    else
        print("Execution error:", result)
    end
end

print()

-- Test 4: Nested if statements
print("=== Test 4: Nested if statements ===")
local code4 = [[
x = 10
y = 20
if x > 5:
    print("x is greater than 5")
    if y > 15:
        print("y is also greater than 15")
        print("Both conditions met")
    else:
        print("y is not greater than 15")
print("End of nested if test")
]]

local bytecode4, error4 = python.compile(code4)
if error4 then
    print("Compilation error:", error4)
else
    print("Bytecode generated successfully")
    print("Executing...")
    local success, result = pcall(python.runBytecode, bytecode4)
    if success then
        print("Execution completed")
    else
        print("Execution error:", result)
    end
end

print()

-- Test 5: Complex conditions
print("=== Test 5: Complex conditions ===")
local code5 = [[
a = 5
b = 10
if a + b > 12:
    print("Sum is greater than 12")
    result = a * b
    print("Product:", result)
elif a - b < 0:
    print("a is less than b")
else:
    print("Other case")
]]

local bytecode5, error5 = python.compile(code5)
if error5 then
    print("Compilation error:", error5)
else
    print("Bytecode generated successfully")
    print("Executing...")
    local success, result = pcall(python.runBytecode, bytecode5)
    if success then
        print("Execution completed")
    else
        print("Execution error:", result)
    end
end
