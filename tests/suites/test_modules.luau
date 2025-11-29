local TestFramework = require("../framework")
local PyLua = require("../../src/PyLua")

local modulesTests: TestFramework.TestSuite = {
	name = "Modules",
	tests = {
		{
			name = "import sys",
			test = function()
				local py = PyLua.new()
				py:execute("import sys")
				local sysPy = py:getGlobalPy("sys")
				TestFramework.assertEqual(sysPy.__type, "module", "sys should be a module")

				-- Check sys.modules
				py:execute("modules = sys.modules")
				local modules = py:getGlobalPy("modules")
				TestFramework.assertEqual(modules.__type, "dict", "sys.modules should be a dict")
			end,
		},
		{
			name = "import sys as s",
			test = function()
				local py = PyLua.new()
				py:execute("import sys as s")
				local s = py:getGlobalPy("s")
				TestFramework.assertEqual(s.__type, "module", "s should be a module")

				local sys = py:getGlobalPy("sys")
				TestFramework.assertEqual(sys, nil, "sys should not be in globals")
			end,
		},
		{
			name = "from sys import modules",
			test = function()
				local py = PyLua.new()
				py:execute("from sys import modules")
				local modules = py:getGlobalPy("modules")
				TestFramework.assertEqual(modules.__type, "dict", "modules should be a dict")
			end,
		},
		{
			name = "from sys import modules as m",
			test = function()
				local py = PyLua.new()
				py:execute("from sys import modules as m")
				local m = py:getGlobalPy("m")
				TestFramework.assertEqual(m.__type, "dict", "m should be a dict")
			end,
		},
		{
			name = "sys.path exists",
			test = function()
				local py = PyLua.new()
				py:execute("import sys")
				local path = py:eval("sys.path")
				TestFramework.assertEqual(path.__type, "list", "sys.path should be a list")
			end,
		},
		{
			name = "sys.path configuration",
			test = function()
				local py = PyLua.new({ searchPath = { "/foo", "/bar" } })
				py:execute("import sys")
				local path = py:eval("sys.path")
				TestFramework.assertEqual(path.__type, "list", "sys.path should be a list")
				local values = path.__value
				TestFramework.assertEqual(#values, 2, "sys.path should have 2 elements")
				TestFramework.assertEqual(values[1].__value, "/foo", "first element should be /foo")
				TestFramework.assertEqual(values[2].__value, "/bar", "second element should be /bar")
			end,
		},
		{
			name = "import non_existent",
			test = function()
				local py = PyLua.new()
				TestFramework.assertError(function()
					py:execute("import non_existent")
					return nil
				end, "ModuleNotFoundError")
			end,
		},
	},
}

TestFramework.runSuite(modulesTests)

return {}
