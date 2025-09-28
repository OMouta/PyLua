--!strict
-- Tests for control flow statements (if, while, for, break, continue)

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
			name = "If Statement - Elif Chain",
			test = function()
				local globals = executeCode([[
x = 5
if x < 0:
	result = "negative"
elif x < 5:
	result = "small"
elif x == 5:
	result = "equal"
else:
	result = "large"
]])
				TestFramework.assertEqual(globals.result, "equal", "Elif chain should select matching branch")
			end,
		},

		{
			name = "If Statement - Elif Else Fallback",
			test = function()
				local globals = executeCode([[
x = -1
if x > 0:
	result = "positive"
elif x == 0:
	result = "zero"
else:
	result = "negative"
]])
				TestFramework.assertEqual(globals.result, "negative", "Elif chain should fall back to else clause")
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

		{
			name = "Compiler - For Loop Bytecode",
			test = function()
				local tokens = Lexer.tokenize("for i in [1, 2, 3]:\n    x = i")
				local ast = Parser.parse(tokens)
				local bytecode = Compiler.compile(ast)

				-- Check that bytecode contains iteration instructions
				local hasGetIter = false
				local hasForIter = false
				for _, instruction in ipairs(bytecode.bytecode) do
					if instruction.opcode == "GET_ITER" then
						hasGetIter = true
					elseif instruction.opcode == "FOR_ITER" then
						hasForIter = true
					end
				end
				TestFramework.assertTrue(hasGetIter, "For loop should generate GET_ITER instruction")
				TestFramework.assertTrue(hasForIter, "For loop should generate FOR_ITER instruction")
			end,
		},

		{
			name = "For Loop - Basic Execution",
			test = function()
				local globals = executeCode([[
total = 0
for i in [1, 2, 3]:
    total = total + i
]])
				TestFramework.assertEqual(globals.total, 6, "For loop should iterate over list elements")
			end,
		},

		{
			name = "For Loop - Empty List",
			test = function()
				local globals = executeCode([[
count = 0
for i in []:
    count = count + 1
]])
				TestFramework.assertEqual(globals.count, 0, "For loop over empty list should not execute body")
			end,
		},

		{
			name = "For Loop - Single Element",
			test = function()
				local globals = executeCode([[
result = 0
for i in [42]:
    result = i
]])
				TestFramework.assertEqual(globals.result, 42, "For loop over single element should work")
			end,
		},

		{
			name = "For Loop - Variable Scope",
			test = function()
				local globals = executeCode([[
for i in [1, 2, 3]:
    pass
result = i
]])
				TestFramework.assertEqual(globals.result, 3, "Loop variable should be accessible after loop ends")
			end,
		},

		{
			name = "For Loop - Nested Loops",
			test = function()
				local globals = executeCode([[
total = 0
for i in [1, 2]:
    for j in [10, 20]:
        total = total + i + j
]])
				-- Expected: (1+10) + (1+20) + (2+10) + (2+20) = 11 + 21 + 12 + 22 = 66
				TestFramework.assertEqual(globals.total, 66, "Nested for loops should work correctly")
			end,
		},

		{
			name = "For Loop - Different Data Types",
			test = function()
				local globals = executeCode([[
result = 0
for i in [1, 2.5, 3]:
    result = result + i
]])
				TestFramework.assertEqual(globals.result, 6.5, "For loop should work with mixed number types")
			end,
		},

		{
			name = "Break Statement - For Loop",
			test = function()
				local globals = executeCode([[
result = 0
for i in [1, 2, 3, 4, 5]:
    if i == 3:
        break
    result = result + i
]])
				TestFramework.assertEqual(globals.result, 3, "Break should exit loop early") -- 1 + 2 = 3
			end,
		},

		{
			name = "Continue Statement - For Loop",
			test = function()
				local globals = executeCode([[
result = 0
for i in [1, 2, 3, 4, 5]:
    if i == 3:
        continue
    result = result + i
]])
				TestFramework.assertEqual(globals.result, 12, "Continue should skip iteration") -- 1 + 2 + 4 + 5 = 12
			end,
		},

		{
			name = "Break Statement - While Loop",
			test = function()
				local globals = executeCode([[
x = 0
while True:
    x = x + 1
    if x >= 3:
        break
]])
				TestFramework.assertEqual(globals.x, 3, "Break should exit while loop")
			end,
		},

		{
			name = "Continue Statement - While Loop",
			test = function()
				local globals = executeCode([[
x = 0
result = 0
while x < 5:
    x = x + 1
    if x == 3:
        continue
    result = result + x
]])
				TestFramework.assertEqual(globals.result, 12, "Continue should skip while iteration") -- 1 + 2 + 4 + 5 = 12
			end,
		},

		{
			name = "Nested Loops with Break",
			test = function()
				local globals = executeCode([[
result = 0
for i in [1, 2, 3]:
    for j in [10, 20, 30]:
        if j == 20:
            break
        result = result + i + j
]])
				-- Expected: (1+10) + (2+10) + (3+10) = 11 + 12 + 13 = 36
				TestFramework.assertEqual(globals.result, 36, "Break should only exit inner loop")
			end,
		},

		{
			name = "Nested Loops with Continue",
			test = function()
				local globals = executeCode([[
result = 0
for i in [1, 2]:
    for j in [10, 20, 30]:
        if j == 20:
            continue
        result = result + i + j
]])
				-- Expected: (1+10) + (1+30) + (2+10) + (2+30) = 11 + 31 + 12 + 32 = 86
				TestFramework.assertEqual(globals.result, 86, "Continue should only skip inner iteration")
			end,
		},
	},
}

TestFramework.runSuite(controlFlowTests)

return {}
