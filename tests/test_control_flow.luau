--!strict
-- Tests for control flow statements (if, while, for, break, continue)

local TestFramework = require("./framework")
local Lexer = require("../src/PyLua/lexer")
local Parser = require("../src/PyLua/parser")
local Compiler = require("../src/PyLua/compiler")
local Interpreter = require("../src/PyLua/vm/interpreter")

-- Helper function to compile and execute Python code
local function executeCode(code: string): { [string]: any }
	local tokens = Lexer.tokenize(code)
	local ast = Parser.parse(tokens)
	local bytecode = Compiler.compile(ast)
	local globals = {}
	Interpreter.execute(bytecode.bytecode, globals, {}, bytecode.constants, bytecode.names)
	return globals
end

-- Test suite for control flow
local controlFlowTests: TestFramework.TestSuite = {
	name = "Control Flow Tests",
	tests = {
		{
			name = "If Statement - True Condition",
			test = function()
				local globals = executeCode([[
x = 5
if x > 3:
	result = "greater"
else:
	result = "not greater"
]])
				TestFramework.assertEqual(globals.result, "greater", "If condition true should execute if body")
			end,
		},

		{
			name = "If Statement - False Condition", 
			test = function()
				local globals = executeCode([[
x = 2
if x > 3:
	result = "greater"
else:
	result = "not greater"
]])
				TestFramework.assertEqual(globals.result, "not greater", "If condition false should execute else body")
			end,
		},

		{
			name = "If Statement - Without Else",
			test = function()
				local globals = executeCode([[
x = 5
result = "initial"
if x > 3:
	result = "changed"
]])
				TestFramework.assertEqual(globals.result, "changed", "If without else should work")
			end,
		},

		{
			name = "While Loop - Basic Execution",
			test = function()
				local globals = executeCode([[
x = 0
while x < 3:
	x = x + 1
]])
				TestFramework.assertEqual(globals.x, 3, "While loop should execute repeatedly")
			end,
		},

		{
			name = "While Loop - False Condition",
			test = function()
				local globals = executeCode([[
x = 5
while x < 3:
	x = x + 1
]])
				TestFramework.assertEqual(globals.x, 5, "While loop with false condition should not execute")
			end,
		},

		{
			name = "Pass Statement",
			test = function()
				local globals = executeCode([[
x = 5
if x > 3:
	pass
else:
	x = 0
]])
				TestFramework.assertEqual(globals.x, 5, "Pass statement should do nothing")
			end,
		},

		{
			name = "Compiler - If Statement Bytecode",
			test = function()
				local tokens = Lexer.tokenize("if x > 3:\n\ty = 1\nelse:\n\ty = 2")
				local ast = Parser.parse(tokens)
				local bytecode = Compiler.compile(ast)
				
				-- Check that bytecode contains control flow instructions
				local hasJump = false
				for _, instruction in ipairs(bytecode.bytecode) do
					if instruction.opcode == "POP_JUMP_IF_FALSE" or instruction.opcode == "JUMP_FORWARD" then
						hasJump = true
						break
					end
				end
				TestFramework.assertTrue(hasJump, "If statement should generate jump instructions")
			end,
		},

		{
			name = "Compiler - While Loop Bytecode", 
			test = function()
				local tokens = Lexer.tokenize("while x < 5:\n\tx = x + 1")
				local ast = Parser.parse(tokens)
				local bytecode = Compiler.compile(ast)
				
				-- Check that bytecode contains loop control instructions
				local hasLoop = false
				for _, instruction in ipairs(bytecode.bytecode) do
					if instruction.opcode == "POP_JUMP_IF_FALSE" or instruction.opcode == "JUMP_FORWARD" then
						hasLoop = true
						break
					end
				end
				TestFramework.assertTrue(hasLoop, "While loop should generate loop instructions")
			end,
		},

		-- Note: Break and continue tests would need more complex setup
		-- since they require loop control flow that's not fully implemented yet
	},
}

TestFramework.runSuite(controlFlowTests)

return {}
