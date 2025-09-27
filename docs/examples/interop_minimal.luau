local PyLua = require("../../src/PyLua")
local python = PyLua.new()

-- Minimal interop: expose a Luau value/function via globals
local globals = python:globals()

-- Expose a simple Luau function that multiplies numbers
globals.lua_mul = function(a: number, b: number): number
    return a * b
end

python:execute([[ 
print("calling into Luau from Python:", lua_mul(6, 7))
result = lua_mul(3, 9)
]])

print("result captured in python globals:", globals.result)
