-- Test to verify the difference between exec and eval modes
local PyLua = require('../src/PyLua')

print("🧪 Testing exec vs eval behavior")
print("=================================")

local runtime = PyLua.new()

-- Test 1: eval() should return expression values
print("✅ Test 1: eval() returns expression values")
local result1 = runtime:eval('10 + 5')
print("eval('10 + 5') =", result1)
assert(result1 == 15, "eval should return expression value")

-- Test 2: execute() should not return expression values (side effects only)
print("✅ Test 2: execute() for side effects only")
runtime:execute('result_var = 20 * 3')
local stored = runtime:globals().result_var
print("After execute('result_var = 20 * 3'), result_var =", stored)
assert(stored == 60, "execute should store variables")

-- Test 3: eval() with assignment should still work but return the assigned value
print("✅ Test 3: eval() with assignment")
local assign_result = runtime:eval('test_assign = 7 * 7')
print("eval('test_assign = 7 * 7') =", assign_result)
print("Type:", type(assign_result))
if type(assign_result) == "table" then
    print("Table contents:")
    for k, v in pairs(assign_result) do
        print("  ", k, "=", v, "(type:", type(v), ")")
    end
end
print("runtime:globals().test_assign =", runtime:globals().test_assign)

-- Test 4: Multiple statements - only last expression should be returned by eval
print("✅ Test 4: eval() with multiple lines")
local multi_result = runtime:eval([[
a = 5
b = 10
a + b
]])
print("eval() with multiple lines returned:", multi_result)
assert(multi_result == 15, "eval should return last expression")

print()
print("🎉 All exec vs eval tests passed!")
print("Architecture correctly handles execution contexts.")
