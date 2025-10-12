--!strict
-- Interop tests ensure Luau ↔ Python conversions behave as expected

local TestFramework = require("../framework")
local PyLua = require("../../src/PyLua")

local interopSuite: TestFramework.TestSuite = {
	name = "Interop Tests",
	tests = {
		{
			name = "Calls Luau Function From Python",
			test = function()
				local python = PyLua.new()
				local globals = python:globals()
				globals.multiply = function(a: number, b: number)
					return a * b
				end
				python:execute("result = multiply(6, 7)")
				local result = python:getGlobal("result")
				TestFramework.assertEqual(result, 42, "Python should call Luau function and receive Luau number")
			end,
		},
		{
			name = "Converts Luau Tables To Python Lists",
			test = function()
				local python = PyLua.new()
				local globals = python:globals()
				globals.numbers = { 1, 2, 3, 4 }
				python:execute("total = sum(numbers)")
				local total = python:getGlobal("total")
				TestFramework.assertEqual(total, 10, "Luau table should behave like Python list")
				local roundTrip = globals.numbers
				TestFramework.assertType(roundTrip, "table", "Proxy should expose Luau table")
				TestFramework.assertEqual(roundTrip[1], 1, "Proxy should preserve values")
			end,
		},
		{
			name = "Returns Python Collections As Luau Tables",
			test = function()
				local python = PyLua.new()
				python:execute([[py_list = [1, 2, 3]
py_dict = {'a': 1, 'b': 2}
]])
				local pyList = python:getGlobal("py_list")
				TestFramework.assertType(pyList, "table", "Python list should convert to Luau table")
				TestFramework.assertEqual(#pyList, 3, "Converted list keeps length")
				TestFramework.assertEqual(pyList[2], 2, "Converted list keeps ordering")
				local pyDict = python:getGlobal("py_dict")
				TestFramework.assertType(pyDict, "table", "Python dict should convert to Luau table")
				TestFramework.assertEqual(pyDict.a, 1, "Dict keys convert to Luau keys")
			end,
		},
		{
			name = "Propagates Luau Errors As Python Exceptions",
			test = function()
				local python = PyLua.new()
				local globals = python:globals()
				globals.fail = function()
					error("ValueError: failing", 0)
				end
				local ok, err = pcall(function()
					python:execute("fail()")
				end)
				TestFramework.assertFalse(ok, "Luau error should surface as Python exception")
				TestFramework.assertTrue(string.find(tostring(err), "ValueError") ~= nil, "Error message should include ValueError")
			end,
		},
	},
}

TestFramework.runSuite(interopSuite)

return {}
