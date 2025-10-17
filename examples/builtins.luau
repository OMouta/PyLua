local PyLua = require("../src/PyLua")
local python = PyLua.new()

python:execute([[ 
print("PyLua Version:", __pylua_version__)

string = "Hello, PyLua!"

print("len of string:", len(string))
print("type of 123:", type(123))

if string[0] == "H":
	print("First character is H")

if isinstance(123, int):
	print("123 is an integer")

# range usage (iterate rather than casting to list)
for i in range(0, 5):
	print("range:", i)
]])
