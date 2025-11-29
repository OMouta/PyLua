local PyLua = require("../../src/PyLua")
local FileSystem = require("../../src/Packages/FileSystem/Lute")

-- Create a Python runtime
local python = PyLua.new({
    fileSystem = FileSystem,
    searchPath = {"examples/imports/libs"}
})

python:execute([[ 
import my_lib
my_lib.pretty_print("Hello from the lute runtime!")
]])