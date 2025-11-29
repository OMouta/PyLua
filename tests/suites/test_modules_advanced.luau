local TestFramework = require("../framework")
local PyLua = require("../../src/PyLua")

local advancedModulesTests = {
	name = "Advanced Modules",
	tests = {
		{
			name = "Native module import",
			test = function()
				local nativeMod = {
					foo = 42,
					bar = function(x: number)
						return x * 2
					end,
				}

				local py = PyLua.new({
					nativeModules = {
						["my_native"] = nativeMod,
					},
				})

				py:execute([[
import my_native
x = my_native.foo
y = my_native.bar(10)
]])
				TestFramework.assertEqual(py:getGlobal("x"), 42)
				TestFramework.assertEqual(py:getGlobal("y"), 20)
			end,
		},
		{
			name = "Virtual filesystem import (file)",
			test = function()
				local files = {
					["/lib/mymod.py"] = "x = 100\ndef get_x(): return x",
				}

				local mockFs = {
					readFile = function(path)
						return files[path]
					end,
					exists = function(path)
						return files[path] ~= nil
					end,
					isDir = function(path)
						return false
					end,
				}

				local py = PyLua.new({
					searchPath = { "/lib" },
					fileSystem = mockFs,
					enableFilesystem = true,
				})

				py:execute([[
import mymod
val_x = mymod.x
]])
				TestFramework.assertEqual(py:getGlobal("val_x"), 100)
			end,
		},
		{
			name = "Virtual filesystem import (package)",
			test = function()
				local files = {
					["/lib/pkg/__init__.py"] = "y = 200",
				}

				local mockFs = {
					readFile = function(path)
						return files[path]
					end,
					exists = function(path)
						if path == "/lib/pkg" then
							return true
						end
						return files[path] ~= nil
					end,
					isDir = function(path)
						return path == "/lib/pkg"
					end,
				}

				local py = PyLua.new({
					searchPath = { "/lib" },
					fileSystem = mockFs,
					enableFilesystem = true,
				})

				py:execute([[
import pkg
val_y = pkg.y
]])
				TestFramework.assertEqual(py:getGlobal("val_y"), 200)
			end,
		},
	},
}

TestFramework.runSuite(advancedModulesTests)

return {}
