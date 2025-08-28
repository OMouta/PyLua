--!strict
-- PyLua Virtual Machine Tests
-- Tests for Phase 4 - VM execution

local TestFramework = require("./framework")
local Interpreter = require("../src/PyLua/vm/interpreter")
local Frame = require("../src/PyLua/vm/frame")
local Stack = require("../src/PyLua/vm/stack")
local Instructions = require("../src/PyLua/bytecode/instructions")

-- VM Test Suite
local vmTests: TestFramework.TestSuite = {
	name = "PyLua Virtual Machine Tests",
	tests = {
		{
			name = "Stack Operations",
			test = function()
				local stack = Stack.new()
				
				-- Test basic push/pop
				Stack.push(stack, 42)
				Stack.push(stack, "hello")
				TestFramework.assertEqual(Stack.size(stack), 2, "Stack should have 2 items")
				TestFramework.assertEqual(Stack.pop(stack), "hello", "Should pop 'hello'")
				TestFramework.assertEqual(Stack.pop(stack), 42, "Should pop 42")
				TestFramework.assertTrue(Stack.isEmpty(stack), "Stack should be empty")
				
				-- Test peek
				Stack.push(stack, 100)
				TestFramework.assertEqual(Stack.peek(stack), 100, "Should peek 100")
				TestFramework.assertEqual(Stack.size(stack), 1, "Stack should still have 1 item")
				
				-- Test rotation operations
				Stack.push(stack, 200)
				Stack.push(stack, 300)
				Stack.rotTwo(stack)
				TestFramework.assertEqual(Stack.pop(stack), 200, "After ROT_TWO, should pop 200")
				TestFramework.assertEqual(Stack.pop(stack), 300, "After ROT_TWO, should pop 300")
				
				-- Test popN
				Stack.push(stack, 1)
				Stack.push(stack, 2)
				Stack.push(stack, 3)
				local values = Stack.popN(stack, 3)
				TestFramework.assertEqual(#values, 3, "Should pop 3 values")
				TestFramework.assertEqual(values[1], 3, "First value should be 3 (top)")
				TestFramework.assertEqual(values[2], 2, "Second value should be 2")
				TestFramework.assertEqual(values[3], 1, "Third value should be 1 (bottom)")
			end,
		},

		{
			name = "Frame Operations",
			test = function()
				local code = {
					Instructions.make("LOAD_CONST", 42),
					Instructions.make("RETURN_VALUE"),
				}
				
				local frame = Frame.new(code, {}, {})
				
				-- Test basic frame properties
				TestFramework.assertEqual(frame.pc, 1, "Frame should start at PC=1")
				TestFramework.assertTrue(Frame.hasNext(frame), "Frame should have next instruction")
				
				-- Test instruction retrieval
				local inst = Frame.getCurrentInstruction(frame)
				TestFramework.assert(inst ~= nil, "Should get current instruction")
				if inst then
					TestFramework.assertEqual(inst.opcode, "LOAD_CONST", "Should get LOAD_CONST")
				end
				
				-- Test advancement
				Frame.advance(frame)
				TestFramework.assertEqual(frame.pc, 2, "PC should advance to 2")
				
				-- Test variable operations
				Frame.setVariable(frame, "test", 123)
				TestFramework.assertEqual(Frame.getVariable(frame, "test"), 123, "Should store and retrieve variable")
				
				-- Test stack operations through frame
				Frame.push(frame, "test_value")
				TestFramework.assertEqual(Frame.stackSize(frame), 1, "Frame stack should have 1 item")
				TestFramework.assertEqual(Frame.pop(frame), "test_value", "Should pop test_value")
			end,
		},

		{
			name = "Basic VM Execution",
			test = function()
				-- Test simple arithmetic: 5 + 3
				local code = {
					Instructions.make("LOAD_CONST", 5),
					Instructions.make("LOAD_CONST", 3),
					Instructions.make("BINARY_ADD"),
					Instructions.make("RETURN_VALUE"),
				}
				
				local result = Interpreter.execute(code)
				TestFramework.assertEqual(result, 8, "5 + 3 should equal 8")
			end,
		},

		{
			name = "Arithmetic Operations",
			test = function()
				-- Test addition
				local addCode = {
					Instructions.make("LOAD_CONST", 10),
					Instructions.make("LOAD_CONST", 5),
					Instructions.make("BINARY_ADD"),
					Instructions.make("RETURN_VALUE"),
				}
				TestFramework.assertEqual(Interpreter.execute(addCode), 15, "10 + 5 = 15")
				
				-- Test subtraction
				local subCode = {
					Instructions.make("LOAD_CONST", 10),
					Instructions.make("LOAD_CONST", 5),
					Instructions.make("BINARY_SUBTRACT"),
					Instructions.make("RETURN_VALUE"),
				}
				TestFramework.assertEqual(Interpreter.execute(subCode), 5, "10 - 5 = 5")
				
				-- Test multiplication
				local mulCode = {
					Instructions.make("LOAD_CONST", 10),
					Instructions.make("LOAD_CONST", 5),
					Instructions.make("BINARY_MULTIPLY"),
					Instructions.make("RETURN_VALUE"),
				}
				TestFramework.assertEqual(Interpreter.execute(mulCode), 50, "10 * 5 = 50")
			end,
		},

		{
			name = "Comparison Operations",
			test = function()
				-- Test less than (op code 0)
				local ltCode = {
					Instructions.make("LOAD_CONST", 5),
					Instructions.make("LOAD_CONST", 10),
					Instructions.make("COMPARE_OP", 0),
					Instructions.make("RETURN_VALUE"),
				}
				TestFramework.assertEqual(Interpreter.execute(ltCode), true, "5 < 10 should be true")
				
				-- Test equality (op code 2)
				local eqCode = {
					Instructions.make("LOAD_CONST", 5),
					Instructions.make("LOAD_CONST", 5),
					Instructions.make("COMPARE_OP", 2),
					Instructions.make("RETURN_VALUE"),
				}
				TestFramework.assertEqual(Interpreter.execute(eqCode), true, "5 == 5 should be true")
			end,
		},

		{
			name = "Collection Building",
			test = function()
				-- Test BUILD_LIST
				local listCode = {
					Instructions.make("LOAD_CONST", 1),
					Instructions.make("LOAD_CONST", 2),
					Instructions.make("LOAD_CONST", 3),
					Instructions.make("BUILD_LIST", 3),
					Instructions.make("RETURN_VALUE"),
				}
				
				local listResult = Interpreter.execute(listCode)
				TestFramework.assertType(listResult, "table", "Should build a list")
				TestFramework.assertEqual(#listResult, 3, "List should have 3 elements")
				TestFramework.assertEqual(listResult[1], 1, "First element should be 1 (bottom of stack)")
				TestFramework.assertEqual(listResult[2], 2, "Second element should be 2")
				TestFramework.assertEqual(listResult[3], 3, "Third element should be 3 (top of stack)")
				
				-- Test BUILD_MAP with constants
				local mapConstants: { any } = { "key1", "value1", "key2", "value2" }
				local mapCode = {
					Instructions.make("LOAD_CONST", 0), -- "key1"
					Instructions.make("LOAD_CONST", 1), -- "value1"
					Instructions.make("LOAD_CONST", 2), -- "key2"
					Instructions.make("LOAD_CONST", 3), -- "value2"
					Instructions.make("BUILD_MAP", 2),
					Instructions.make("RETURN_VALUE"),
				}
				
				local mapResult = Interpreter.execute(mapCode, {}, {}, mapConstants)
				TestFramework.assertType(mapResult, "table", "Should build a map")
				TestFramework.assertEqual(mapResult["key1"], "value1", "Should have key1 -> value1")
				TestFramework.assertEqual(mapResult["key2"], "value2", "Should have key2 -> value2")
			end,
		},

		{
			name = "Control Flow",
			test = function()
				-- Test conditional jump (POP_JUMP_IF_FALSE)
				-- Load true, jump if false (should not jump), load 42, return
				local constants: { any } = { true, 42, 99 }
				local jumpCode = {
					Instructions.make("LOAD_CONST", 0), -- true
					Instructions.make("POP_JUMP_IF_FALSE", 5), -- Jump to instruction 5 if false
					Instructions.make("LOAD_CONST", 1), -- 42 - This should execute
					Instructions.make("JUMP_FORWARD", 1), -- Skip next instruction
					Instructions.make("LOAD_CONST", 2), -- 99 - This should be skipped
					Instructions.make("RETURN_VALUE"),
				}
				
				local jumpResult = Interpreter.execute(jumpCode, {}, {}, constants)
				TestFramework.assertEqual(jumpResult, 42, "Should execute conditional path correctly")
			end,
		},

		{
			name = "Unary Operations",
			test = function()
				-- Test unary negative
				local negCode = {
					Instructions.make("LOAD_CONST", 42),
					Instructions.make("UNARY_NEGATIVE"),
					Instructions.make("RETURN_VALUE"),
				}
				TestFramework.assertEqual(Interpreter.execute(negCode), -42, "Unary negative should work")
				
				-- Test unary positive (identity)
				local posCode = {
					Instructions.make("LOAD_CONST", 42),
					Instructions.make("UNARY_POSITIVE"),
					Instructions.make("RETURN_VALUE"),
				}
				TestFramework.assertEqual(Interpreter.execute(posCode), 42, "Unary positive should be identity")
			end,
		},
	},
}

TestFramework.runSuite(vmTests)

return {}
