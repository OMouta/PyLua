local PyLua = require("../../src/PyLua")
local python = PyLua.new()

python:execute([[ 
def add(a, b):
    return a + b

def greet(name):
    return "Hello, " + name

print("add(2, 3) =", add(2, 3))
print(greet("World"))
]])

-- You can also evaluate expressions and read back results
local result = python:eval("add(10, 32)")
print("add(10,32) ->", result)
