local Python = require('../src/PyLua/python')

-- Simple while loop bytecode test
local bytecode = Python.compile([[
    x = 0
    while x < 3:
        x = x + 1
]])

print("While loop bytecode:")
print(bytecode)
