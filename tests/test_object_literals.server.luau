-- Test Python object literals (lists, dictionaries, tuples, sets) in PyLua compiler
local python = require('../src/PyLua/python')

-- Test 1: List literals
print("=== Test 1: List literals ===")
local code1 = [==[
empty_list = []
numbers = [1, 2, 3]
mixed = [1, "hello", True]
nested = [[1, 2], [3, 4]]
print("empty_list:", empty_list)
print("numbers:", numbers)
print("mixed:", mixed)
print("nested:", nested)
print("numbers length:", len(numbers))
]==]

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

-- Test 2: Dictionary literals
print("=== Test 2: Dictionary literals ===")
local code2 = [[
empty_dict = {}
print("empty_dict")
person = {"name": "John", "age": 30}
mixed_keys = {1: "one", "two": 2, 3.5: "three-half"}
nested_dict = {"info": {"name": "Alice", "city": "NYC"}}
print("empty_dict:", empty_dict)
print("person:", person)
print("mixed_keys:", mixed_keys)
print("nested_dict:", nested_dict)
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

-- Test 3: Tuple literals
print("=== Test 3: Tuple literals ===")
local code3 = [[
empty_tuple = ()
coordinates = (10, 20)
rgb = (255, 128, 0)
nested_tuple = ((1, 2), (3, 4))
single_item = (42,)
print("empty_tuple:", empty_tuple)
print("coordinates:", coordinates)
print("rgb:", rgb)
print("nested_tuple:", nested_tuple)
print("single_item:", single_item)
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

-- Test 4: Set literals
print("=== Test 4: Set literals ===")
local code4 = [[
unique_numbers = {1, 2, 3, 2, 1}
mixed_set = {1, "hello", True}
print("unique_numbers:", unique_numbers)
print("mixed_set:", mixed_set)
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

-- Test 5: Complex nested structures
print("=== Test 5: Complex nested structures ===")
local code5 = [==[
complex_data = {
    "lists": [[1, 2], [3, 4, 5]],
    "info": {"name": "Test", "active": True},
    "coordinates": (100, 200),
    "tags": {"python", "lua", "bytecode"}
}
print("complex_data:", complex_data)
]==]

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

-- Test 6: Object literal operations
print("=== Test 6: Object literal operations ===")
local code6 = [[
# List operations
numbers = [1, 2, 3]
print("numbers before append:", numbers)
print("numbers length before:", len(numbers))
numbers.append(4)
print("numbers after append:", numbers)
print("numbers length after:", len(numbers))

# Dictionary operations
person = {"name": "John", "age": 30}
print("person before update:", person)
print("person keys before:", len(person))
person["city"] = "NYC"
print("person after update:", person)
print("person keys after:", len(person))
print("person name:", person["name"])
print("person city:", person["city"])

# Tuple access
coords = (10, 20, 30)
print("coords tuple:", coords)
print("coords length:", len(coords))
print("x coordinate:", coords[0])
print("y coordinate:", coords[1])
print("z coordinate:", coords[2])
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
