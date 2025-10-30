--!strict
-- Tests for generator functions and yield semantics

local TestFramework = require("../framework")
local Lexer = require("../../src/PyLua/lexer")
local Parser = require("../../src/PyLua/parser")
local Compiler = require("../../src/PyLua/compiler")
local Interpreter = require("../../src/PyLua/vm/interpreter")
local Builtins = require("../../src/PyLua/builtins/functions")

local function executeCode(code: string): { [string]: any }
	local tokens = Lexer.tokenize(code)
	local ast = Parser.parse(tokens)
	local bytecode = Compiler.compile(ast)
	local globals = {}
	local builtins = Builtins.createBuiltins()
	Interpreter.execute(bytecode.bytecode, globals, builtins, bytecode.constants, bytecode.names)
	return globals
end

local generatorTests: TestFramework.TestSuite = {
	name = "Generator Tests",
	tests = {
		{
			name = "Basic generator yields",
			test = function()
				local globals = executeCode([[
def counter():
    yield 1
    yield 2
    yield 3

values = []
gen = counter()
values.append(next(gen))
values.append(next(gen))
values.append(next(gen))
try:
    next(gen)
    exhausted = False
except StopIteration:
    exhausted = True
]])
				local values = globals.values
				TestFramework.assert(values ~= nil, "Expected results list to exist")
				local listObj = values :: any
				local inner = listObj.__value :: { any }
				TestFramework.assertEqual(#inner, 3, "Generator should yield exactly three values")
				TestFramework.assertEqual(inner[1].__value, 1, "First yield should be 1")
				TestFramework.assertEqual(inner[2].__value, 2, "Second yield should be 2")
				TestFramework.assertEqual(inner[3].__value, 3, "Third yield should be 3")
				TestFramework.assert(globals.exhausted == true, "Generator should raise StopIteration when exhausted")
			end,
		},
		{
			name = "next builtin uses default",
			test = function()
				local globals = executeCode([[
def empty():
    if False:
        yield None

g = empty()
value = next(g, 123)
]])
				TestFramework.assertEqual(globals.value, 123, "next() should return provided default when iterator is exhausted")
			end,
		},
		{
			name = "Generator iterates in for loop",
			test = function()
				local globals = executeCode([[
def letters():
    yield "a"
    yield "b"
    yield "c"

seen = []
for value in letters():
    seen.append(value)
]])
				local seen = globals.seen
				TestFramework.assert(seen ~= nil, "Expected collected values list")
				local data = seen.__value :: { any }
				TestFramework.assertEqual(#data, 3, "For loop should exhaust generator")
				TestFramework.assertEqual(data[1].__value, "a", "First entry should match first yield")
				TestFramework.assertEqual(data[2].__value, "b", "Second entry should match second yield")
				TestFramework.assertEqual(data[3].__value, "c", "Third entry should match third yield")
			end,
		},
		{
			name = "Generator return value surfaces on StopIteration",
			test = function()
				local globals = executeCode([[
def gen():
    yield "step"
    return 99

g = gen()
first = next(g)
status = "not raised"
final = None
try:
    next(g)
except StopIteration as exc:
    status = "raised"
    final = exc.value
]])
				TestFramework.assertEqual(globals.first, "step", "First yielded value should be captured")
				TestFramework.assertEqual(globals.status, "raised", "Generator should raise StopIteration when exhausted")
				TestFramework.assertEqual(globals.final, 99, "StopIteration.value should expose generator return value")
			end,
		},
	},
}

TestFramework.runSuite(generatorTests)

return {}
