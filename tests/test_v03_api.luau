-- Test for PyLua v0.3 API (Runtime-based architecture)
local PyLua = require('../src/PyLua')

print("🧪 Testing PyLua v0.3 API")
print("==========================")

-- Test 1: Basic runtime creation and evaluation
print("✅ Test 1: Basic runtime creation")
local python = PyLua.new()
local result = python:eval('2 + 3')
print("2 + 3 =", result)
print("Type:", type(result))
if type(result) == "table" then
    print("Table contents:")
    for k, v in pairs(result) do
        print("  ", k, "=", v)
    end
end
assert(result == 5, "Basic evaluation failed")

-- Test 2: Multiple isolated runtimes
print("✅ Test 2: Multiple isolated runtimes")
local runtime1 = PyLua.new()
local runtime2 = PyLua.new()

runtime1:globals().x = 10
runtime2:globals().x = 20

local result1 = runtime1:eval('x * 2')
local result2 = runtime2:eval('x * 2')

print("Runtime 1: x * 2 =", result1)
print("Runtime 2: x * 2 =", result2)
assert(result1 == 20, "Runtime 1 isolation failed")
assert(result2 == 40, "Runtime 2 isolation failed")

-- Test 3: Execute method (side effects only)
print("✅ Test 3: Execute method")
local runtime3 = PyLua.new()
runtime3:execute('message = "Hello from Python!"')
local stored_message = runtime3:globals().message
print("Stored message:", stored_message)

-- Test 4: Custom functions in globals
print("✅ Test 4: Custom functions")
local runtime4 = PyLua.new()
runtime4:globals().luau_add = function(a: any, b: any)
    return a + b + 100
end

local custom_result = runtime4:eval('luau_add(5, 3)')
print("Custom function result:", custom_result)
assert(custom_result == 108, "Custom function failed")

-- Test 5: Runtime with debug option
print("✅ Test 5: Runtime options")
local debug_runtime = PyLua.new({debug = true})
debug_runtime:execute('debug_var = 42')

-- Test 6: Advanced bytecode API
print("✅ Test 6: Advanced bytecode API")
local runtime5 = PyLua.new()
local bytecode = runtime5:compile('result = 10 * 5')
local exec_result = runtime5:runBytecode(bytecode)
print("Bytecode execution completed")
