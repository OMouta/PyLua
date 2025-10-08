--!strict
-- Tests for Python function support

local TestFramework = require("../framework")
local Lexer = require("../../src/PyLua/lexer")
local Parser = require("../../src/PyLua/parser")
local Compiler = require("../../src/PyLua/compiler")
local Interpreter = require("../../src/PyLua/vm/interpreter")

-- Helper function to compile and execute Python code
local function executeCode(code: string): { [string]: any }
	local tokens = Lexer.tokenize(code)
	local ast = Parser.parse(tokens)
	local bytecode = Compiler.compile(ast)
	local globals = {}
	Interpreter.execute(bytecode.bytecode, globals, {}, bytecode.constants, bytecode.names)
	return globals
end

-- Test suite for functions
local functionTests: TestFramework.TestSuite = {
	name = "Function Tests",
	tests = {
		{
			name = "Simple Function Definition",
			test = function()
				local globals = executeCode([[
def test_func():
	pass

result = test_func
]])
				-- Function should be defined in globals
				TestFramework.assert(globals.test_func ~= nil, "Function should be defined")
				TestFramework.assert(globals.result ~= nil, "Function assignment should work")
			end,
		},

		{
			name = "Function with Return Value",
			test = function()
				local globals = executeCode([[
def get_value():
	return 42

result = get_value()
]])
				TestFramework.assertEqual(globals.result, 42, "Function should return correct value")
			end,
		},

		{
			name = "Function with Arguments",
			test = function()
				local globals = executeCode([[
def add_numbers(a, b):
	return a + b

result = add_numbers(3, 4)
]])
				TestFramework.assertEqual(globals.result, 7, "Function should handle arguments correctly")
			end,
		},

		{
			name = "Function with Local Variables",
			test = function()
				local globals = executeCode([[
def calculate():
	x = 10
	y = 20
	return x + y

result = calculate()
]])
				TestFramework.assertEqual(globals.result, 30, "Function should handle local variables")
				-- Local variables should not leak to global scope
				TestFramework.assert(globals.x == nil, "Local variable x should not be in global scope")
				TestFramework.assert(globals.y == nil, "Local variable y should not be in global scope")
			end,
		},

		{
			name = "Multiple Function Calls",
			test = function()
				local globals = executeCode([[
def double(x):
	return x * 2

result1 = double(5)
result2 = double(10)
]])
				TestFramework.assertEqual(globals.result1, 10, "First function call should work")
				TestFramework.assertEqual(globals.result2, 20, "Second function call should work")
			end,
		},

		{
			name = "Function Calling Function",
			test = function()
				local globals = executeCode([[
def helper(x):
	return x + 1

def main(x):
	return helper(x) * 2

result = main(5)
]])
				TestFramework.assertEqual(globals.result, 12, "Function should be able to call other functions")
			end,
		},

		{
			name = "Function with Single Default Argument",
			test = function()
				local globals = executeCode([[
def greet(name, greeting="Hello"):
	return greeting

result1 = greet("Alice", "Hi")
result2 = greet("Bob")
]])
				TestFramework.assertEqual(globals.result1, "Hi", "Explicit argument should override default")
				TestFramework.assertEqual(globals.result2, "Hello", "Should use default argument value")
			end,
		},

		{
			name = "Function with Multiple Default Arguments",
			test = function()
				local globals = executeCode([[
def add(a, b=5, c=10):
	return a + b + c

result1 = add(1, 2, 3)
result2 = add(1, 2)
result3 = add(1)
]])
				TestFramework.assertEqual(globals.result1, 6, "All arguments explicitly provided")
				TestFramework.assertEqual(globals.result2, 13, "Should use default for c")
				TestFramework.assertEqual(globals.result3, 16, "Should use defaults for b and c")
			end,
		},

		{
			name = "Default Arguments with Expressions",
			test = function()
				local globals = executeCode([[
def compute(x, y=2*3):
	return x * y

result1 = compute(5)
result2 = compute(5, 10)
]])
				TestFramework.assertEqual(globals.result1, 30, "Should evaluate default expression (2*3=6, 5*6=30)")
				TestFramework.assertEqual(globals.result2, 50, "Explicit argument should override default expression")
			end,
		},

		{
			name = "Function with All Defaults",
			test = function()
				local globals = executeCode([[
def get_value(x=42):
	return x

result1 = get_value()
result2 = get_value(100)
]])
				TestFramework.assertEqual(globals.result1, 42, "Should use default when no argument provided")
				TestFramework.assertEqual(globals.result2, 100, "Should use provided argument")
			end,
		},
	},
}

TestFramework.runSuite(functionTests)

return {}
