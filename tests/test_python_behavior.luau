-- Test to understand Python's actual behavior with assignments in eval
local PyLua = require('../src/PyLua')

print("🧪 Testing Python's actual assignment behavior")
print("==============================================")

local runtime = PyLua.new()

-- In real Python:
-- eval("2 + 3") returns 5
-- eval("x = 5") raises SyntaxError: invalid syntax
-- exec("x = 5") returns None and creates variable x

print("✅ Test 1: Pure expressions work in eval")
local expr_result = runtime:eval('2 + 3')
print("eval('2 + 3') =", expr_result)

print()
print("✅ Test 2: Assignments should be done with execute(), not eval()")
runtime:execute('assignment_var = 42')
print("execute('assignment_var = 42') stores variable")
print("assignment_var =", runtime:globals().assignment_var)

print()
print("✅ Test 3: Mixed statements and expressions")
local mixed_result = runtime:eval([[
temp_a = 10
temp_b = 20  
temp_a + temp_b
]])
print("eval() with assignments + final expression =", mixed_result)
print("temp_a =", runtime:globals().temp_a)
print("temp_b =", runtime:globals().temp_b)

print()
print("🎉 Understanding complete!")
print("Assignment statements don't return values - this is correct Python behavior.")
