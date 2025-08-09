--!strict
-- Tests for Phase 3.2 Built-in Types (numbers, strings, booleans, None, type objects placeholder)

local TestFramework = require("./framework")
local base = require("../src/PyLua/objects/base")
local builtins = require("../src/PyLua/objects/builtins")

local suite: TestFramework.TestSuite = {
	name = "PyLua Built-in Types",
	tests = {
		{
			name = "None singleton",
			test = function()
				local n1 = builtins.None()
				local n2 = builtins.None()
				TestFramework.assertTrue(n1 == n2, "None should be singleton reference")
				TestFramework.assertEqual(n1.__type, "NoneType", "Type is NoneType")
				TestFramework.assertFalse(base.truthy(n1), "None is falsy")
			end,
		},
		{
			name = "Boolean values",
			test = function()
				local t = builtins.True()
				local f = builtins.False()
				TestFramework.assertEqual(t.__type, "bool", "True type bool")
				TestFramework.assertTrue(base.truthy(t), "True truthy")
				TestFramework.assertFalse(base.truthy(f), "False falsy")
			end,
		},
		{
			name = "Int arithmetic",
			test = function()
				local a = builtins.Int(2)
				local b = builtins.Int(3)
				local sum = base.operate("add", a, b)
				TestFramework.assertEqual(sum.__value, 5, "2 + 3 = 5")
				local prod = base.operate("mul", a, b)
				TestFramework.assertEqual(prod.__value, 6, "2 * 3 = 6")
				local sub = base.operate("sub", b, a)
				TestFramework.assertEqual(sub.__value, 1, "3 - 2 = 1")
			end,
		},
		{
			name = "Float promotion",
			test = function()
				local a = builtins.Int(2)
				local b = builtins.Float(0.5)
				local result = base.operate("add", a, b)
				TestFramework.assertEqual(result.__type, "float", "int + float -> float")
				TestFramework.assertEqual(result.__value, 2.5, "2 + 0.5 = 2.5")
			end,
		},
		{
			name = "Division yields float",
			test = function()
				local a = builtins.Int(5)
				local b = builtins.Int(2)
				local div = base.operate("truediv", a, b)
				TestFramework.assertEqual(div.__type, "float", "Division returns float")
				TestFramework.assertEqual(div.__value, 2.5, "5 / 2 = 2.5")
			end,
		},
		{
			name = "String concatenation and repetition",
			test = function()
				local s1 = builtins.Str("ab")
				local s2 = builtins.Str("cd")
				local cat = base.operate("add", s1, s2)
				TestFramework.assertEqual(cat.__value, "abcd", "Concatenate")
				local times = base.operate("mul", s1, builtins.Int(3))
				TestFramework.assertEqual(times.__value, "ababab", "Repeat 3x")
			end,
		},
		{
			name = "Truthiness basics",
			test = function()
				TestFramework.assertFalse(base.truthy(builtins.Str("")), "Empty string falsy")
				TestFramework.assertTrue(base.truthy(builtins.Str("x")), "Non-empty string truthy")
				TestFramework.assertFalse(base.truthy(builtins.Int(0)), "Zero int falsy")
				TestFramework.assertTrue(base.truthy(builtins.Int(7)), "Non-zero int truthy")
			end,
		},
		{
			name = "Error on unsupported operand",
			test = function()
				local a = builtins.Int(1)
				TestFramework.assertError(function(): any
					return base.operate("add", a, builtins.Str("x"))
				end, "int + str should error")
			end,
		},
	},
}

TestFramework.runSuite(suite)

return {}
