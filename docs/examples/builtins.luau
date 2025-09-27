local PyLua = require("../../src/PyLua")
local python = PyLua.new()

python:execute([[ 
print("PyLua Version:", __pylua_version__)

print("len of string:", len("hello"))
print("type of 123:", type(123))

if isinstance(123, int):
	print("123 is an integer")

# range usage (iterate rather than casting to list)
for i in range(0, 5):
	print("range:", i)
]])
