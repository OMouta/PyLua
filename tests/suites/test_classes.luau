--!strict
-- Tests for Python class definitions and inheritance

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

local classTests: TestFramework.TestSuite = {
	name = "Class Tests",
	tests = {
		{
			name = "Class attributes accessible via instances",
			test = function()
				local globals = executeCode([[class Box:
    value = 5

box = Box()
inst_value = box.value
class_value = Box.value
]])
				TestFramework.assertEqual(globals.inst_value, 5, "Instance attribute should match class value")
				TestFramework.assertEqual(globals.class_value, 5, "Class attribute read should succeed")
			end,
		},
		{
			name = "__init__ and method binding",
			test = function()
				local globals = executeCode([[class Counter:
    def __init__(self, start):
        self.count = start
    def inc(self):
        self.count = self.count + 1

counter = Counter(3)
counter.inc()
after = counter.count
]])
				TestFramework.assert(globals.after ~= nil, "Counter should expose updated field")
				TestFramework.assertEqual(globals.after, 4, "Method should have incremented state")
			end,
		},
		{
			name = "Inheritance shares base methods",
			test = function()
				local globals = executeCode([[class Animal:
    def value(self):
        return 41

class Dog(Animal):
    pass

dog = Dog()
answer = dog.value()
]])
				TestFramework.assert(globals.answer ~= nil, "Method call should return value")
				TestFramework.assertEqual(globals.answer, 41, "Subclass should inherit base methods")
			end,
		},
		{
			name = "isinstance recognizes inheritance",
			test = function()
				local globals = executeCode([[class Base:
    pass

class Child(Base):
    pass

item = Child()
is_base = isinstance(item, Base)
is_child = isinstance(item, Child)
is_tuple = isinstance(item, (int, Child))
]])
				TestFramework.assertEqual(globals.is_base, true, "Child should be instance of Base")
				TestFramework.assertEqual(globals.is_child, true, "Child should be instance of Child")
				TestFramework.assertEqual(globals.is_tuple, true, "Tuple target should short-circuit on matching type")
			end,
		},
		{
			name = "Explicit object base is accepted",
			test = function()
				local globals = executeCode([[class Ident(object):
    pass

inst = Ident()
]])
				TestFramework.assert(globals.inst ~= nil, "Instance should be created when using explicit object base")
			end,
		},
		{
			name = "super() calls base __init__",
			test = function()
				local globals = executeCode([[class Base:
    def __init__(self, value):
        self.tag = "Base:" + value

class Child(Base):
    def __init__(self, value):
        super().__init__(value)
        self.tag = self.tag + "->Child"

child = Child("X")
result = child.tag
]])
				TestFramework.assertEqual(globals.result, "Base:X->Child", "super() should invoke parent __init__")
			end,
		},
		{
			name = "super explicit arguments",
			test = function()
				local globals = executeCode([[class Parent:
    def greet(self):
        return "parent"

class Kid(Parent):
    def greet(self):
        sup = super(Kid, self)
        return sup.greet() + " and child"

k = Kid()
greeting = k.greet()
]])
				TestFramework.assertEqual(globals.greeting, "parent and child", "super with explicit arguments should access base methods")
			end,
		},
	},
}

TestFramework.runSuite(classTests)

return {}
