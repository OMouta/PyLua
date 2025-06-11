-- Test nested control flow structures in PyLua compiler
-- Testing loops inside if statements and if statements inside loops
local python = require('../src/PyLua/python')

-- Test 1: For loop inside if statement
print("=== Test 1: For loop inside if statement ===")
local code1 = [[
x = 5
if x > 3:
    print("x is greater than 3, iterating:")
    for i in range(3):
        print("  iteration:", i)
    print("Done with loop")
else:
    print("x is not greater than 3")
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

-- Test 2: While loop inside if statement
print("=== Test 2: While loop inside if statement ===")
local code2 = [[
condition = True
if condition:
    print("Starting while loop")
    i = 0
    while i < 3:
        print("  while iteration:", i)
        i = i + 1
    print("While loop finished")
print("After if-while combination")
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

-- Test 3: If statement inside for loop
print("=== Test 3: If statement inside for loop ===")
local code3 = [[
print("Testing numbers 1 to 5:")
for num in range(1, 6):
    if num % 2 == 0:
        print(num, "is even")
    else:
        print(num, "is odd")
print("Number classification complete")
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

-- Test 4: If statement inside while loop
print("=== Test 4: If statement inside while loop ===")
local code4 = [[
counter = 0
print("Counting with conditions:")
while counter < 5:
    if counter == 0:
        print("Starting count")
    elif counter == 2:
        print("Halfway there")
    elif counter == 4:
        print("Almost done")
    else:
        print("Counter is:", counter)
    counter = counter + 1
print("Counting finished")
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

-- Test 5: Complex nested structure - loop in if in loop
print("=== Test 5: Complex nested structure ===")
local code5 = [[
print("Complex nesting test:")
for outer in range(2):
    print("Outer loop:", outer)
    if outer == 0:
        print("  First outer iteration - inner loop:")
        for inner in range(2):
            print("    Inner:", inner)
    else:
        print("  Second outer iteration - no inner loop")
print("Complex nesting complete")
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

print()

-- Test 6: Multiple loops in if/elif/else
print("=== Test 6: Multiple loops in if/elif/else ===")
local code6 = [[
choice = 2
if choice == 1:
    print("Choice 1 - counting up:")
    for i in range(3):
        print("  up:", i)
elif choice == 2:
    print("Choice 2 - counting down:")
    i = 2
    while i >= 0:
        print("  down:", i)
        i = i - 1
else:
    print("Choice 3 - no counting")
print("Multiple loop choice complete")
]]

local bytecode6, error6 = python.compile(code6)
if error6 then
    print("Compilation error:", error6)
else
    print("Bytecode generated successfully")
    print("Executing...")
    local success, result = pcall(python.runBytecode, bytecode6)
    if success then
        print("Execution completed")
    else
        print("Execution error:", result)
    end
end

print()

-- Test 7: Nested while loops with conditions
print("=== Test 7: Nested while loops with conditions ===")
local code7 = [[
x = 0
print("Nested while loops:")
while x < 2:
    print("Outer x:", x)
    y = 0
    while y < 2:
        if x == y:
            print("  x equals y:", x)
        else:
            print("  x != y:", x, "!=", y)
        y = y + 1
    x = x + 1
print("Nested while loops complete")
]]

local bytecode7, error7 = python.compile(code7)
if error7 then
    print("Compilation error:", error7)
else
    print("Bytecode generated successfully")
    print("Executing...")
    local success, result = pcall(python.runBytecode, bytecode7)
    if success then
        print("Execution completed")
    else
        print("Execution error:", result)
    end
end
