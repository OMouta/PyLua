local PyLua = require("../src/PyLua")

-- Create a Python runtime
local python = PyLua.new()

-- Execute multi-line Python code (statements)
python:execute([[ 
x = 10
y = 32
print("sum:", x + y)
]])

-- Evaluate a Python expression and get the result in Luau
local value = python:eval("1 + 2 * 3")
print("eval result:", value) -- 7

-- Share values via the globals table
python:execute("z = 5")
local globals = python:globals()
print("z from python globals:", globals.z) -- 5
