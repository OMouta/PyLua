--!strict
-- Tests for Phase 3.3 Collections

local TestFramework = require("./framework")
local base = require("../src/PyLua/objects/base")
local builtins = require("../src/PyLua/objects/builtins")
local collections = require("../src/PyLua/objects/collections")

local suite: TestFramework.TestSuite = {
	name = "PyLua Collections",
	tests = {
		{
			name = "Create and append list",
			test = function()
				local lst = collections.list({ builtins.Int(1), builtins.Int(2) })
				TestFramework.assertEqual(lst.__type, "list", "Type list")
				local appendMethod = base.getattr(lst, "append")
				base.call(appendMethod, { builtins.Int(3) })
				TestFramework.assertEqual(#lst.__value, 3, "List length 3")
			end,
		},
		{
			name = "List pop and concat",
			test = function()
				local a = collections.list({ builtins.Int(1), builtins.Int(2) })
				local b = collections.list({ builtins.Int(3) })
				local add = base.getattr(a, "__add__")
				local combined = base.call(add, { b })
				TestFramework.assertEqual(#combined.__value, 3, "Concat length 3")
				local popMethod = base.getattr(combined, "pop")
				local last = base.call(popMethod, {})
				TestFramework.assertEqual(last.__value, 3, "Popped 3")
				TestFramework.assertEqual(#combined.__value, 2, "Length now 2")
			end,
		},
		{
			name = "Tuple creation and length",
			test = function()
				local t = collections.tuple({ builtins.Int(1), builtins.Int(2), builtins.Int(3) })
				local lenMethod = base.getattr(t, "__len__")
				local ln = base.call(lenMethod, {})
				TestFramework.assertEqual(ln.__value, 3, "Tuple len 3")
			end,
		},
		{
			name = "Dict set and get",
			test = function()
				local d = collections.dict(nil)
				local setM = base.getattr(d, "set")
				local setArgs: { base.PyObject } = {} :: any
				setArgs[1] = builtins.Str("a")
				setArgs[2] = builtins.Int(10)
				base.call(setM, setArgs)
				local getM = base.getattr(d, "get")
				local getArgs: { base.PyObject } = {} :: any
				getArgs[1] = builtins.Str("a")
				local value = base.call(getM, getArgs)
				TestFramework.assertEqual(value.__value, 10, "dict['a']=10")
			end,
		},
		{
			name = "Set add and length",
			test = function()
				local s = collections.set({ builtins.Int(1) })
				local addM = base.getattr(s, "add")
				base.call(addM, { builtins.Int(2) })
				base.call(addM, { builtins.Int(2) }) -- duplicate
				local lenM = base.getattr(s, "__len__")
				local ln = base.call(lenM, {})
				TestFramework.assertEqual(ln.__value, 2, "Set size 2")
			end,
		},
		{
			name = "List iteration",
			test = function()
				local lst = collections.list({ builtins.Int(1), builtins.Int(2), builtins.Int(3) })
				local iterM = base.getattr(lst, "__iter__")
				local iter = base.call(iterM, {})
				local nextM = base.getattr(iter, "__next__")
				local sum = 0
				for _ = 1, 3 do
					local v = base.call(nextM, {})
					sum += v.__value
				end
				TestFramework.assertEqual(sum, 6, "Sum 1+2+3=6")
				TestFramework.assertError(function(): any
					return base.call(nextM, {})
				end, "Expect StopIteration")
			end,
		},
		{
			name = "Dict get default",
			test = function()
				local d = collections.dict(nil)
				local getM = base.getattr(d, "get")
				local missArgs: { base.PyObject } = {} :: any
				missArgs[1] = builtins.Str("missing")
				missArgs[2] = builtins.Int(99)
				local defaultValue = base.call(getM, missArgs)
				TestFramework.assertEqual(defaultValue.__value, 99, "Default returned")
			end,
		},
		{
			name = "Collection truthiness",
			test = function()
				local emptyList = collections.list(nil)
				TestFramework.assertFalse(base.truthy(emptyList), "Empty list falsy")
				local nonEmptyList = collections.list({ builtins.Int(1) })
				TestFramework.assertTrue(base.truthy(nonEmptyList), "Non-empty list truthy")
				local emptyDict = collections.dict(nil)
				TestFramework.assertFalse(base.truthy(emptyDict), "Empty dict falsy")
				local d = collections.dict(nil)
				local setM = base.getattr(d, "set")
				local args: { base.PyObject } = {} :: any
				args[1] = builtins.Str("k")
				args[2] = builtins.Int(1)
				base.call(setM, args)
				TestFramework.assertTrue(base.truthy(d), "Non-empty dict truthy")
			end,
		},
	},
}

TestFramework.runSuite(suite)

return {}
