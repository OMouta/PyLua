--!strict
-- Tests for Python built-in functions implemented in Phase 5

local TestFramework = require("./framework")
local Lexer = require("../src/PyLua/lexer")
local Parser = require("../src/PyLua/parser")
local Compiler = require("../src/PyLua/compiler")
local Interpreter = require("../src/PyLua/vm/interpreter")
local BuiltinFunctions = require("../src/PyLua/builtins/functions")

local function executeCode(code: string, builtins: { [string]: any }?): { [string]: any }
	local tokens = Lexer.tokenize(code)
	local ast = Parser.parse(tokens)
	local bytecode = Compiler.compile(ast)
	local globals = {}
	Interpreter.execute(
		bytecode.bytecode,
		globals,
		builtins or BuiltinFunctions.createBuiltins(),
		bytecode.constants,
		bytecode.names
	)
	return globals
end

local builtinTests: TestFramework.TestSuite = {
	name = "Built-in Function Tests",
	tests = {
		{
			name = "print outputs joined text",
			test = function()
				local captured = {}
				BuiltinFunctions.setWriter(function(text)
					table.insert(captured, text)
				end)
				local builtins = BuiltinFunctions.createBuiltins()
				local globals = executeCode([[result = print("Hello", 123)]], builtins)
				BuiltinFunctions.setWriter(nil)
				TestFramework.assertEqual(#captured, 1, "print should produce one output line")
				TestFramework.assertEqual(captured[1], "Hello 123", "print should join arguments with spaces")
				TestFramework.assert(globals.result == nil, "print() should return None (nil in Luau)")
			end,
		},
		{
			name = "len and type return expected values",
			test = function()
				local globals = executeCode([[length = len([1, 2, 3])
type_result = type(42)]])
				TestFramework.assertEqual(globals.length, 3, "len() should return sequence length")
				TestFramework.assert(globals.type_result ~= nil, "type() should return a PyObject")
				TestFramework.assertEqual(globals.type_result.__type, "type", "type() should return type object")
				TestFramework.assertEqual(globals.type_result.__value.name, "int", "type() should reflect operand type")
			end,
		},
		{
			name = "range produces correct sequences",
			test = function()
				local globals = executeCode([[forward_sum = 0
for i in range(1, 5):
    forward_sum = forward_sum + i
forward_len = len(range(1, 5))

reverse_sum = 0
for i in range(5, 0, -2):
    reverse_sum = reverse_sum + i
reverse_len = len(range(5, 0, -2))
]])
				TestFramework.assertEqual(globals.forward_sum, 10, "range(1,5) should yield sum 10")
				TestFramework.assertEqual(globals.forward_len, 4, "len(range(1,5)) should be 4")
				TestFramework.assertEqual(globals.reverse_sum, 9, "range with negative step should sum to 9")
				TestFramework.assertEqual(globals.reverse_len, 3, "len(range(5,0,-2)) should be 3")
			end,
		},
		{
			name = "numeric conversion builtins",
			test = function()
				local globals = executeCode([[int_val = int(3.9)
float_val = float(5)
true_val = bool(7)
false_val = bool(0)
str_val = str(123)
]])
				TestFramework.assertEqual(globals.int_val, 3, "int() should truncate towards zero")
				TestFramework.assertEqual(globals.float_val, 5, "float() should convert ints to float")
				TestFramework.assertEqual(globals.true_val, true, "bool() should treat non-zero as True")
				TestFramework.assertEqual(globals.false_val, false, "bool() should treat zero as False")
				TestFramework.assertEqual(globals.str_val, "123", "str() should stringify argument")
			end,
		},
		{
			name = "aggregate and bytes builtins",
			test = function()
				local globals = executeCode([[sum_val = sum([1, 2, 3], 4)
min_val = min(9, 3, 7)
max_val = max(range(1, 5))
bytes_a = bytes("AB")
bytes_b = bytes([65, 67])
]])
				TestFramework.assertEqual(globals.sum_val, 10, "sum() should include start value")
				TestFramework.assertEqual(globals.min_val, 3, "min() should select smallest")
				TestFramework.assertEqual(globals.max_val, 4, "max() should evaluate iterable")
				TestFramework.assert(globals.bytes_a ~= nil, "bytes() should return PyObject")
				TestFramework.assertEqual(globals.bytes_a.__type, "bytes", "bytes() should create bytes object")
				TestFramework.assertEqual(globals.bytes_a.__value, "AB", "bytes(str) should use underlying string")
				TestFramework.assertEqual(globals.bytes_b.__value, "AC", "bytes(list[int]) should build string from ints")
			end,
		},
	},
}

TestFramework.runSuite(builtinTests)

return {}
