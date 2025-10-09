--!strict
-- Tests for exception handling (try/except)

local TestFramework = require("../framework")
local Lexer = require("../../src/PyLua/lexer")
local Parser = require("../../src/PyLua/parser")
local Compiler = require("../../src/PyLua/compiler")
local Interpreter = require("../../src/PyLua/vm/interpreter")
local BuiltinFunctions = require("../../src/PyLua/builtins/functions")

local function executeCode(code: string): { [string]: any }
	local tokens = Lexer.tokenize(code)
	local ast = Parser.parse(tokens)
	local bytecode = Compiler.compile(ast)
	local globals = {}
	local builtins = BuiltinFunctions.createBuiltins()
	Interpreter.execute(bytecode.bytecode, globals, builtins, bytecode.constants, bytecode.names)
	return globals
end

local exceptionTests: TestFramework.TestSuite = {
	name = "Exception Handling",
	tests = {
		{
			name = "ValueError caught with alias",
			test = function()
				local globals = executeCode([[ 
result = "unset"
err_type = None
try:
	int("abc")
except ValueError as err:
	result = str(err)
	err_type = type(err)
]])
				local expectedMessage = "ValueError: invalid literal for int() with base 10"
				local actualMessage = globals.result
				local debugMessage = "ValueError message should propagate into handler (got '" .. tostring(actualMessage) .. "')"
				TestFramework.assertEqual(actualMessage, expectedMessage, debugMessage)
				local typeObj = globals.err_type
				TestFramework.assertType(typeObj, "table", "type() should return a PyObject table")
				TestFramework.assertEqual(typeObj.__value.name, "ValueError", "type(err) should report ValueError")
			end,
		},
		{
			name = "Else block executes when no exception",
			test = function()
				local globals = executeCode([[ 
result = "unset"
try:
	x = 5
except ValueError:
	result = "caught"
else:
	result = "no error"
]])
				TestFramework.assertEqual(globals.result, "no error", "Else clause should run when try succeeds")
			end,
		},
		{
			name = "Ordered handlers evaluate sequentially",
			test = function()
				local globals = executeCode([[ 
result = "unset"
try:
	int("abc")
except TypeError:
	result = "type"
except ValueError:
	result = "value"
]])
				TestFramework.assertEqual(globals.result, "value", "Matching handler should execute in order")
			end,
		},
		{
			name = "Bare except captures NameError",
			test = function()
				local globals = executeCode([[ 
result = "unset"
try:
	missing_variable
except:
	result = "caught"
]])
				TestFramework.assertEqual(globals.result, "caught", "Bare except should catch NameError")
			end,
		},
		{
			name = "Unhandled exception propagates",
			test = function()
				TestFramework.assertError(function()
					return executeCode([[ 
try:
	int("abc")
except TypeError:
	result = "type"
]])
				end, "Unhandled exceptions should propagate out of try")
			end,
		},
		{
			name = "Tuple handler captures ValueError",
			test = function()
				local globals = executeCode([[ 
result = "unset"
try:
	int("abc")
except (TypeError, ValueError) as err:
	result = str(err)
]])
				local expected = "ValueError: invalid literal for int() with base 10"
				TestFramework.assertEqual(globals.result, expected, "Tuple except should match any provided type")
			end,
		},
		{
			name = "Finally executes on success",
			test = function()
				local globals = executeCode([[ 
log = ""
try:
	log += "body"
finally:
	log += "finally"
]])
				TestFramework.assertEqual(globals.log, "bodyfinally", "Finally block should run after successful try")
			end,
		},
		{
			name = "Finally executes before exception handler",
			test = function()
				local globals = executeCode([[ 
log = ""
try:
	try:
		int("abc")
	finally:
		log += "F"
except ValueError:
	log += "E"
]])
				TestFramework.assertEqual(globals.log, "FE", "Finally should run before matching except handler")
			end,
		},
		{
			name = "Finally executes before return",
			test = function()
				local globals = executeCode([[ 
log = []
def run():
	try:
		log.append("body")
		return "done"
	finally:
		log.append("finally")
result = run()
]])
				TestFramework.assertEqual(globals.result, "done", "Function should return original value")
				local logObj = globals.log
				TestFramework.assertType(logObj, "table", "log should be a PyObject list")
				local entries = logObj.__value
				TestFramework.assertEqual(#entries, 2, "Finally should record entry even on return")
				TestFramework.assertEqual(entries[2].__value, "finally", "Finally entry should be appended after body entry")
			end,
		},
		{
			name = "Finally executes on break",
			test = function()
				local globals = executeCode([[ 
log = ""
for item in [1, 2, 3]:
	try:
		log += "L"
		break
	finally:
		log += "F"
]])
				TestFramework.assertEqual(globals.log, "LF", "Finally should execute even when breaking out of loop")
			end,
		},
	},
}

TestFramework.runSuite(exceptionTests)

return {}
