local Python = require('../src/PyLua/python')

local bytecode = Python.compile([[
    x = 10
    y = "hello world"
    print(y, x)
]])

print(bytecode)

local result, variables = Python.runBytecode(bytecode)
print("Execution result:", result)
print("Variables after execution:")
for name, value in pairs(variables) do
    print("  " .. name .. " = " .. tostring(value))
end

bytecode = Python.compile([[
    i = 10
    for x in range(5):
        i = i + 1
    print(i)
]])

print(bytecode)

result, variables = Python.runBytecode(bytecode)
print("Execution result:", result)
print("Variables after execution:")
for name, value in pairs(variables) do
    print("  " .. name .. " = " .. tostring(value))
end