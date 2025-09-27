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
		{
			name = "repr ascii format builtins",
			test = function()
				local globals = executeCode([[repr_val = repr("hi")
ascii_val = ascii("hi")
fmt_num = format(3.14159, ".2f")
fmt_str = format("hi", "5s")
]])
				TestFramework.assertEqual(globals.repr_val, "'hi'", "repr() should wrap string in quotes")
				TestFramework.assertEqual(globals.ascii_val, "'hi'", "ascii() should fall back to repr for ASCII strings")
				TestFramework.assertEqual(globals.fmt_num, "3.14", "format() should respect numeric spec")
				TestFramework.assertEqual(globals.fmt_str, "   hi", "format() should honor width for strings")
			end,
		},
		{
			name = "string representations for types and containers",
			test = function()
				local globals = executeCode([[type_text = str(type(123))
list_text = str([1, "hi"])
tuple_text = str((1,))
dict_text = str({'a': 1, 'b': 2})
set_text = str({1, 2})
]])
				TestFramework.assertEqual(globals.type_text, "<class 'int'>", "str(type(x)) should show class name")
				TestFramework.assertEqual(globals.list_text, "[1, 'hi']", "str(list) should show repr of elements")
				TestFramework.assertEqual(globals.tuple_text, "(1,)", "Single-element tuple should include trailing comma")
				TestFramework.assertEqual(globals.dict_text, "{'a': 1, 'b': 2}", "dict repr should include key-value pairs")
				TestFramework.assertEqual(globals.set_text, "{1, 2}", "set repr should list elements")
			end,
		},
		{
			name = "print emits repr-like formatting for containers",
			test = function()
				local captured = {}
				BuiltinFunctions.setWriter(function(text)
					table.insert(captured, text)
				end)
				local builtins = BuiltinFunctions.createBuiltins()
				executeCode([[print("type:", type(123))
nums = [1, 2, "hi"]
print("nums:", nums)
pair = (1, 2)
print("pair:", pair)
conf = {'a': 1, 'b': 2}
print("conf:", conf)
letters = {1, 2}
print("letters:", letters)
]], builtins)
				BuiltinFunctions.setWriter(nil)
				TestFramework.assertEqual(captured[1], "type: <class 'int'>", "print(type(x)) should show class repr")
				TestFramework.assertEqual(captured[2], "nums: [1, 2, 'hi']", "print(list) should use list repr")
				TestFramework.assertEqual(captured[3], "pair: (1, 2)", "print(tuple) should use tuple repr")
				TestFramework.assertEqual(captured[4], "conf: {'a': 1, 'b': 2}", "print(dict) should include mapping repr")
				TestFramework.assertEqual(captured[5], "letters: {1, 2}", "print(set) should show set repr")
			end,
		},
		{
			name = "isinstance builtin behavior",
			test = function()
				local globals = executeCode([[is_int = isinstance(5, int)
is_str = isinstance("hi", int)
is_compound = isinstance("hi", (int, str))
bool_as_int = isinstance(True, int)
empty_check = isinstance(5, ())
is_type_type = isinstance(type(5), type)
]])
				TestFramework.assertEqual(globals.is_int, true, "5 should be instance of int")
				TestFramework.assertEqual(globals.is_str, false, "string should not be instance of int")
				TestFramework.assertEqual(globals.is_compound, true, "tuple of types should check any")
				TestFramework.assertEqual(globals.bool_as_int, true, "bool should be considered an int subtype")
				TestFramework.assertEqual(globals.empty_check, false, "empty tuple should yield False")
				TestFramework.assertEqual(globals.is_type_type, true, "type objects should be instances of type")
				TestFramework.assertError(function()
					return executeCode([[bad = isinstance(5, 5)]])
				end, "Invalid isinstance target should raise TypeError")
			end,
		},
		{
			name = "Bytes indexing from Python code",
			test = function()
				local globals = executeCode([[b = b"hello"
first = b[0]
last = b[-1]
combined = b + b" world"
]])
				TestFramework.assertEqual(globals.first, 104, "First byte should be ASCII for 'h'")
				TestFramework.assertEqual(globals.last, 111, "Negative indexing should yield last byte")
				TestFramework.assertEqual(globals.combined.__type, "bytes", "Concatenation should stay bytes")
				TestFramework.assertEqual(globals.combined.__value, "hello world", "Bytes concatenation should join values")
			end,
		},
		{
			name = "List methods and indexing from Python code",
			test = function()
				local globals = executeCode([[values = [1, 2]
values.append(3)
values[0] = 9
values[-1] = 4
length = len(values)
first = values[0]
last = values[-1]
contains_two = 2 in values
contains_four = 4 in values
contains_five = 5 in values
]])
				local values = globals.values
				TestFramework.assert(values ~= nil, "values list should exist")
				TestFramework.assertEqual(values.__type, "list", "values should be a PyObject list")
				TestFramework.assertEqual(globals.length, 3, "List length should reflect append")
				TestFramework.assertEqual(globals.first, 9, "First element should be updated")
				TestFramework.assertEqual(globals.last, 4, "Negative index assignment should update last element")
				TestFramework.assertEqual(globals.contains_two, true, "2 should remain in list")
				TestFramework.assertEqual(globals.contains_four, true, "4 should be in list after assignment")
				TestFramework.assertEqual(globals.contains_five, false, "5 should not be in list")
			end,
		},
		{
			name = "F-string evaluation",
			test = function()
				local globals = executeCode([[name = "World"
value = 3.14159
result = f"Hello {name}"
formatted = f"{value:.2f}"
escaped = f"{{name}}"
repr_val = f"{name!r}"
]])
				TestFramework.assertEqual(globals.result, "Hello World", "F-string should interpolate names")
				TestFramework.assertEqual(globals.formatted, "3.14", "F-string format spec should apply")
				TestFramework.assertEqual(globals.escaped, "{name}", "Double braces should escape")
				TestFramework.assertEqual(globals.repr_val, "'World'", "!r conversion should use repr")
			end,
		},
	},
}

TestFramework.runSuite(builtinTests)

return {}
