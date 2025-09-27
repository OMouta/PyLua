local PyLua = require("../../src/PyLua")

local python = PyLua.new()

python:execute([[

print("Hello world from python!")
print("PyLua Version:", __pylua_version__)

]])