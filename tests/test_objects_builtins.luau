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
			name = "builtins.bytes basic construction",
			test = function()
				local b1 = builtins.Bytes("")
				TestFramework.assertEqual(b1.__type, "bytes", "empty bytes failed")
				TestFramework.assertEqual(b1.__value, "", "empty bytes value failed")
				local b2 = builtins.Bytes({65, 66, 67})
				TestFramework.assertEqual(b2.__value, "ABC", "bytes from table failed")
				local b3 = builtins.Bytes("\255\001")
				TestFramework.assertEqual(#(b3.__value), 2, "bytes from string failed")
			end,
		},

		{
			name = "builtins.bytes len and getitem",
			test = function()
				local b = builtins.Bytes({0, 1, 2, 255})
				local len = base.call(base.getattr(b, "__len__"), {})
				TestFramework.assertEqual(len.__type, "int", "bytes __len__ type failed")
				TestFramework.assertEqual(len.__value, 4, "bytes __len__ failed")
				local get0 = base.call(base.getattr(b, "__getitem__"), { builtins.Int(0) })
				TestFramework.assertEqual(get0.__type, "int", "getitem 0 type failed")
				TestFramework.assertEqual(get0.__value, 0, "getitem 0 failed")
				local getLast = base.call(base.getattr(b, "__getitem__"), { builtins.Int(-1) })
				TestFramework.assertEqual(getLast.__value, 255, "getitem -1 failed")
			end,
		},

		{
			name = "builtins.bytes eq and repr",
			test = function()
				local b1 = builtins.Bytes({65, 66})
				local b2 = builtins.Bytes("AB")
				local eq = base.call(base.getattr(b1, "__eq__"), { b2 })
				TestFramework.assertEqual(eq.__type, "bool", "bytes __eq__ type failed")
				TestFramework.assertEqual(eq.__value, true, "bytes __eq__ failed")
				local r = base.call(base.getattr(b1, "__repr__"), {})
				TestFramework.assertEqual(r.__type, "str", "bytes __repr__ type failed")
				TestFramework.assertEqual(r.__value, "b'AB'", "bytes __repr__ basic failed")
			end,
		},

		{
			name = "builtins.bytes add and mul",
			test = function()
				local a = builtins.Bytes("A")
				local b = builtins.Bytes("B")
				local cat = base.operate("add", a, b)
				TestFramework.assertEqual(cat.__type, "bytes", "bytes add type")
				TestFramework.assertEqual(cat.__value, "AB", "bytes add value")
				local rep = base.operate("mul", a, builtins.Int(3))
				TestFramework.assertEqual(rep.__value, "AAA", "bytes mul value")
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
