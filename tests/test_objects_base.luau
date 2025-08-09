--!strict
-- PyLua Object System Tests - Phase 3.1 Base Object System

local TestFramework = require("./framework")
local base = require("../src/PyLua/objects/base")

local tests: TestFramework.TestSuite = {
	name = "PyLua Base Object System",
	tests = {
		{
			name = "Create primitive objects via ensurePyObject",
			test = function()
				local i = base.ensurePyObject(5)
				TestFramework.assertEqual(i.__type, "int", "Integers infer int type")
				local f = base.ensurePyObject(3.14)
				TestFramework.assertEqual(f.__type, "float", "Floats infer float type")
				local s = base.ensurePyObject("hi")
				TestFramework.assertEqual(s.__type, "str", "Strings infer str type")
				local bTrue = base.ensurePyObject(true)
				TestFramework.assertEqual(bTrue.__type, "bool", "Boolean true type")
				local none = base.ensurePyObject(nil)
				TestFramework.assertEqual(none.__type, "NoneType", "nil maps to NoneType")
			end,
		},
		{
			name = "Register custom type and create object",
			test = function()
				local t = base.registerType("Custom", {})
				local obj = base.newPyObject("Custom", {})
				TestFramework.assertEqual(obj.__type, "Custom", "Custom object has type")
				local snap = base.typeRegistrySnapshot()
				TestFramework.assertTrue(snap.Custom == true, "Type present in registry")
			end,
		},
		{
			name = "Set and get simple attribute",
			test = function()
				local obj = base.newPyObject("object", {})
				local val = base.ensurePyObject(10)
				base.setattr(obj, "x", val)
				local attr = base.getattr(obj, "x")
				TestFramework.assertEqual(attr.__type, "int", "Attribute retrieved")
				TestFramework.assertTrue(base.hasattr(obj, "x"), "hasattr true")
				TestFramework.assertFalse(base.hasattr(obj, "missing"), "hasattr false")
			end,
		},
		{
			name = "Method resolution and bound method call",
			test = function()
				-- Register a type with a method
				local t = base.registerType("Point", {
					methods = {
						magnitude = function(selfObj)
							-- selfObj.__value assumed table with x,y
							local data: any = selfObj.__value
							local mag = math.sqrt(
								(data.x :: number) * (data.x :: number) + (data.y :: number) * (data.y :: number)
							)
							-- Force float representation even if integer
							return base.newFloat(mag)
						end,
					},
				})
				local p = base.newPyObject("Point", { x = 3, y = 4 })
				local magMethod = base.getattr(p, "magnitude")
				TestFramework.assertEqual(magMethod.__type, "builtin_function_or_method", "Bound method type")
				local result = base.call(magMethod, {})
				TestFramework.assertTrue(result.__type == "float" or result.__type == "int", "Numeric result type")
				TestFramework.assertEqual(math.floor(result.__value + 0.5), 5, "Magnitude 5")
			end,
		},
		{
			name = "__getattr fallback mechanism",
			test = function()
				local dynType = base.registerType("Dynamic", {
					__getattr = function(selfObj, name: string)
						if name == "forty_two" then
							return base.ensurePyObject(42)
						end
						return nil :: any
					end,
				})
				local d = base.newPyObject("Dynamic", {})
				local v = base.getattr(d, "forty_two")
				TestFramework.assertEqual(v.__type, "int", "Dynamic attribute produced")
				TestFramework.assertError(function(): any
					return base.getattr(d, "other")
				end, "Missing dynamic attr errors")
			end,
		},
		{
			name = "__setattr hook",
			test = function()
				local storage: { [string]: any } = {}
				local hookType = base.registerType("Hooked", {
					__setattr = function(selfObj, name: string, value)
						storage[name] = value.__value
					end,
				})
				local h = base.newPyObject("Hooked", {})
				base.setattr(h, "a", base.ensurePyObject(7))
				TestFramework.assertEqual(storage.a, 7, "Custom setattr executed")
				-- getattr should still error (not stored in dict)
				TestFramework.assertError(function(): any
					return base.getattr(h, "a")
				end, "Attribute not actually in dict")
			end,
		},
		{
			name = "Calling non-callable raises error",
			test = function()
				local obj = base.newPyObject("object", {})
				TestFramework.assertError(function(): any
					return base.call(obj, {})
				end, "Non callable should error")
			end,
		},
	},
}

TestFramework.runSuite(tests)

return {}
