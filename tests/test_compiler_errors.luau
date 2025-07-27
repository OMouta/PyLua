-- Test PyLua compiler error improvements
local compiler = require('../src/PyLua/compiler/compiler')

-- Helper function to test error cases
local function testError(testName: string, code: string, expectedToFail: boolean)
    print("=== " .. testName .. " ===")
    local success, result = pcall(function()
        return compiler.compile(code)
    end)
    
    if not success then
        print("Error caught (expected):")
        print(result)
    else
        if expectedToFail then
            print("ERROR: Should have failed!")
        else
            print("SUCCESS: Compiled successfully")
        end
    end
    print("")
end

-- Test 1: Missing colon in function definition
testError("Test 1: Missing colon in function definition", [[
def hello(name)
    print("Hello " + name)
]], true)

-- Test 2: Invalid assignment
testError("Test 2: Invalid assignment", [[
x = 5
y[2 = 10
]], true)

-- Test 3: Missing 'in' in for loop
testError("Test 3: Missing 'in' in for loop", [[
for x range(10):
    print(x)
]], true)

-- Test 4: Invalid number literal
testError("Test 4: Invalid number literal", [[
x = 123abc
]], true)

-- Test 5: Missing comma in function parameters
testError("Test 5: Missing comma in function parameters", [[
def greet(name age):
    print("Hello " + name)
]], true)

-- Test 6: Missing closing parenthesis in function call
testError("Test 6: Missing closing parenthesis in function call", [[
x = print("hello"
y = 5
]], true)

-- Test 7: Missing closing bracket in list
testError("Test 7: Missing closing bracket in list", [[
numbers = [1, 2, 3
print(numbers)
]], true)

-- Test 8: Missing closing brace in dictionary
testError("Test 8: Missing closing brace in dictionary", [[
person = {"name": "John", "age": 30
print(person)
]], true)

-- Test 9: Invalid dictionary syntax (missing colon)
testError("Test 9: Invalid dictionary syntax (missing colon)", [[
person = {"name" "John", "age": 30}
]], true)

-- Test 10: Missing closing parenthesis in tuple
testError("Test 10: Missing closing parenthesis in tuple", [[
coords = (10, 20
print(coords)
]], true)

-- Test 11: Invalid attribute access (missing identifier)
testError("Test 11: Invalid attribute access (missing identifier)", [[
obj = {"name": "test"}
value = obj.
]], true)

-- Test 12: Missing closing bracket in indexing
testError("Test 12: Missing closing bracket in indexing", [[
arr = [1, 2, 3]
value = arr[0
]], true)

-- Test 13: Unknown binary operator
testError("Test 13: Unknown binary operator", [[
x = 5 *** 3
]], true)

-- Test 14: Missing 'while' keyword
testError("Test 14: Missing while condition", [[
x = 0
x < 10:
    x = x + 1
]], false)

-- Test 15: Missing colon after while condition
testError("Test 15: Missing colon after while condition", [[
x = 0
while x < 10
    x = x + 1
]], true)

-- Test 16: Missing colon after if condition
testError("Test 16: Missing colon after if condition", [[
x = 5
if x > 0
    print("positive")
]], true)

-- Test 17: Missing colon after else
testError("Test 17: Missing colon after else", [[
x = 5
if x > 0:
    print("positive")
else
    print("not positive")
]], true)

-- Test 18: Unexpected end of expression
testError("Test 18: Unexpected end of expression", [[
x = 5 +
]], true)

-- Test 19: Missing function parameter name
testError("Test 19: Missing function parameter name", [[
def calculate(a, , c):
    return a + c
]], true)

-- Test 20: Valid code (should not fail)
testError("Test 20: Valid code (should not fail)", [[
def greet(name):
    print("Hello " + name)

greet("World")
]], false)

print("=== All tests completed ===")
