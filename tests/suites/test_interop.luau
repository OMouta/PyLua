--!strict
-- Interop tests ensure Luau ↔ Python conversions behave as expected

local TestFramework = require("../framework")
local PyLua = require("../../src/PyLua")
local Bridge = require("../../src/PyLua/interop/bridge")

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
		{
			name = "Binds Luau Tables As Python Objects",
			test = function()
				Bridge.clearClassBindings()
				Bridge.registerClassBinding({
					pyTypeName = "Widget",
					predicate = function(value: any): boolean
						return type(value) == "table" and value.__kind == "Widget"
					end,
				})
				local python = PyLua.new()
				local widget = {
					__kind = "Widget",
					value = 5,
					increment = function(self: any, amount: number)
						self.value += amount
						return self.value
					end,
				}
				python:setGlobal("widget", widget)
				python:execute([[before = widget.value
after = widget.increment(7)
widget.value = after + 1]])
				local before = python:getGlobal("before")
				local after = python:getGlobal("after")
				TestFramework.assertEqual(before, 5, "Python should see initial attribute value")
				TestFramework.assertEqual(after, 12, "Method binding should return updated value")
				TestFramework.assertEqual(widget.value, 13, "Python assignment should update Luau table")
				local roundTrip = python:getGlobal("widget")
				TestFramework.assertEqual(roundTrip, widget, "Proxy should roundtrip original table")
			end,
		},
		{
			name = "Supports Non Self-Bound Methods",
			test = function()
				Bridge.clearClassBindings()
				Bridge.registerClassBinding({
					pyTypeName = "Utility",
					predicate = function(value: any): boolean
						return type(value) == "table" and value.__kind == "Utility"
					end,
					bindSelf = false,
				})
				local python = PyLua.new()
				local utility = {
					__kind = "Utility",
					double = function(amount: number)
						return amount * 2
					end,
				}
				python:setGlobal("utility", utility)
				python:execute("result = utility.double(6)")
				local result = python:getGlobal("result")
				TestFramework.assertEqual(result, 12, "bindSelf=false should avoid injecting table")
				local roundTrip = python:getGlobal("utility")
				TestFramework.assertEqual(roundTrip, utility, "Utility should roundtrip to original table")
			end,
		},
		{
			name = "Supports Custom Attribute Setters",
			test = function()
				Bridge.clearClassBindings()
				Bridge.registerClassBinding({
					pyTypeName = "Counter",
					predicate = function(value: any): boolean
						return type(value) == "table" and value.__kind == "Counter"
					end,
					setAttr = function(target, attr, newValue)
						if attr == "value" then
							target.value = math.floor(newValue)
						else
							target[attr] = newValue
						end
					end,
				})
				local python = PyLua.new()
				local counter = {
					__kind = "Counter",
					value = 0,
				}
				python:setGlobal("counter", counter)
				python:execute("counter.value = 7.9")
				TestFramework.assertEqual(counter.value, 7, "Custom setter should coerce values")
			end,
		},
	},
}

TestFramework.runSuite(interopSuite)

return {}
