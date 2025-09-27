local PyLua = require("../../src/PyLua")

local python = PyLua.new()

python:execute([[

print("Hello world from python!")

]])