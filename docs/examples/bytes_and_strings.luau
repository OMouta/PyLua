local PyLua = require("../../src/PyLua")
local python = PyLua.new()

python:execute([[ 
s = "hello"
b = b"hello"
print("str:", s)
print("bytes:", b)
print("len(bytes):", len(b))
print("b[1] (first byte):", b[0])
print("concat bytes:", b + b" world")
]])
