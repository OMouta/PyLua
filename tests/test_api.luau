--!strict
-- PyLua API Tests
-- Test the main PyLua API interface

local TestFramework = require("./framework")
local PyLua = require("../src/PyLua")

-- Test suite for PyLua API
local apiTests: TestFramework.TestSuite = {
	name = "PyLua API Tests",
	tests = {
		{
			name = "Create Runtime Instance",
			test = function()
				local python = PyLua.new()
				TestFramework.assertType(python, "table", "Runtime should be a table")

				-- Test with options
				local pythonWithOpts = PyLua.new({ debug = true, timeout = 10 })
				TestFramework.assertType(pythonWithOpts, "table", "Runtime with options should be a table")
			end,
		},

		{
			name = "Runtime Methods Exist",
			test = function()
				local python = PyLua.new()

				TestFramework.assertType(python.execute, "function", "execute method should exist")
				TestFramework.assertType(python.eval, "function", "eval method should exist")
				TestFramework.assertType(python.compile, "function", "compile method should exist")
				TestFramework.assertType(python.runBytecode, "function", "runBytecode method should exist")
				TestFramework.assertType(python.globals, "function", "globals method should exist")
				TestFramework.assertType(python.setGlobal, "function", "setGlobal method should exist")
				TestFramework.assertType(python.getGlobal, "function", "getGlobal method should exist")
			end,
		},

		{
			name = "Global Variable Access",
			test = function()
				local python = PyLua.new()

				-- Set and get global
				python:setGlobal("test_var", 42)
				local value = python:getGlobal("test_var")
				TestFramework.assertEqual(value, 42, "Global variable should be retrievable")

				-- Access globals table
				local globals = python:globals()
				TestFramework.assertEqual(globals.test_var, 42, "Global should be in globals table")
			end,
		},

		{
			name = "Version Information",
			test = function()
				TestFramework.assertType(PyLua.version, "string", "Version should be a string")
				TestFramework.assertType(PyLua.description, "string", "Description should be a string")

				-- Version should contain "0.3"
				TestFramework.assert(string.find(PyLua.version, "0.3") ~= nil, "Version should contain '0.3'")
			end,
		},
	},
}

TestFramework.runSuite(apiTests)

return {}
