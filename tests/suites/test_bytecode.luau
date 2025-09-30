--!strict
-- PyLua Bytecode / Compiler Tests (Phase 4.1 minimal subset)

local TestFramework = require("../framework")
local Lexer = require("../../src/PyLua/lexer")
local Parser = require("../../src/PyLua/parser")
local Compiler = require("../../src/PyLua/compiler")
local instr = require("../../src/PyLua/bytecode/instructions")
local Collections = require("../../src/PyLua/objects/collections")
local Base = require("../../src/PyLua/objects/base")
local Interpreter = require("../../src/PyLua/vm/interpreter")

local function compileSource(src: string)
	local tokens = Lexer.tokenize(src)
	local ast = Parser.parse(tokens)
	return Compiler.compile(ast)
end

local bytecodeTests: TestFramework.TestSuite = {
	name = "Bytecode Compiler Tests",
	tests = {
		{
			name = "Compile constant expression at module level",
			test = function()
				local code = compileSource("42")
				-- Expect: LOAD_CONST 0; POP_TOP; LOAD_CONST <None>; RETURN_VALUE
				TestFramework.assertTrue(#code.bytecode >= 4, "At least 4 instructions")
				TestFramework.assertEqual(code.bytecode[1].opcode, "LOAD_CONST", "First LOAD_CONST")
				TestFramework.assertEqual(code.constants[1], 42, "Const 42 present (index 0)")
			end,
		},
		{
			name = "Compile simple assignment",
			test = function()
				local code = compileSource("x = 1")
				-- LOAD_CONST 0; STORE_NAME 0; LOAD_CONST None; RETURN_VALUE
				TestFramework.assertEqual(code.bytecode[1].opcode, "LOAD_CONST", "Load const")
				TestFramework.assertEqual(code.bytecode[2].opcode, "STORE_NAME", "Store name")
				TestFramework.assertEqual(code.names[1], "x", "Name x recorded")
			end,
		},
		{
			name = "Compile chained comparison emits short-circuit sequence",
			test = function()
				local code = compileSource("a < b < c")
				local opcodesSeen: { string } = {}
				for _, instruction in ipairs(code.bytecode) do
					opcodesSeen[#opcodesSeen + 1] = instruction.opcode
				end
				local joined = table.concat(opcodesSeen, ",")
				TestFramework.assertTrue(
					string.find(joined, "DUP_TOP", 1, true) ~= nil,
					"Should duplicate comparator for chaining"
				)
				TestFramework.assertTrue(
					string.find(joined, "ROT_THREE", 1, true) ~= nil,
					"Should rotate stack to preserve operands"
				)
				TestFramework.assertTrue(
					string.find(joined, "JUMP_IF_FALSE_OR_POP", 1, true) ~= nil,
					"Should short-circuit on failed comparison"
				)
				local compareCount = 0
				for _, opcode in ipairs(opcodesSeen) do
					if opcode == "COMPARE_OP" then
						compareCount += 1
					end
				end
				TestFramework.assertEqual(compareCount, 2, "Should emit COMPARE_OP for each comparator")
				TestFramework.assertTrue(
					string.find(joined, "ROT_TWO", 1, true) ~= nil,
					"Should rotate stack during cleanup"
				)
				TestFramework.assertTrue(
					string.find(joined, "POP_TOP", 1, true) ~= nil,
					"Should remove duplicated operand on early exit"
				)
			end,
		},
		{
			name = "Compile binary addition expression statement",
			test = function()
				local code = compileSource("1 + 2")
				-- LOAD_CONST a; LOAD_CONST b; BINARY_ADD; POP_TOP; LOAD_CONST None; RETURN_VALUE
				local ops = {}
				for _, ins in ipairs(code.bytecode) do
					table.insert(ops, ins.opcode)
				end
				local joined = table.concat(ops, ",")
				TestFramework.assertTrue(string.find(joined, "BINARY_ADD") ~= nil, "Contains BINARY_ADD")
			end,
		},
		{
			name = "Compile return inside function-like synthetic module wrapper",
			test = function()
				-- Simulate by directly compiling a Return node (not via parser for now)
				local returnAst = {
					type = "Module",
					body = {
						{
							type = "Return",
							value = { type = "Constant", value = 5, lineno = 1, col_offset = 0 },
							lineno = 1,
							col_offset = 0,
						},
					},
					lineno = 1,
					col_offset = 0,
				}
				local code = Compiler.compile(returnAst)
				local last = code.bytecode[#code.bytecode]
				TestFramework.assertEqual(last.opcode, "RETURN_VALUE", "Ends with RETURN_VALUE")
			end,
		},
		{
			name = "Instruction rendering utility",
			test = function()
				local code = compileSource("1 + 2")
				local rendered = instr.renderAll(code.bytecode)
				TestFramework.assertTrue(#rendered > 0, "Rendered lines produced")
			end,
		},
		{
			name = "Compile and execute bytes literal",
			test = function()
				-- Compile expression so result is returned
				local tokens = Lexer.tokenize("b'AB'")
				local exprAst = Parser.parseExpression(tokens)
				local code = Compiler.compile(exprAst)
				-- Execute via interpreter to realize bytes object
				local result = Interpreter.execute(code.bytecode, {}, {}, code.constants, code.names)
				TestFramework.assertType(result, "table", "Result should be PyObject")
				TestFramework.assertEqual(result.__type, "bytes", "Type should be bytes")
				TestFramework.assertEqual(result.__value, "AB", "Bytes content should match")
			end,
		},
		{
			name = "Compile list comprehension and execute",
			test = function()
				local tokens = Lexer.tokenize("[x for x in data]")
				local exprAst = Parser.parseExpression(tokens)
				local code = Compiler.compile(exprAst)
				local dataList = Collections.newList({ Base.newInt(1), Base.newInt(2), Base.newInt(3) })
				local globals = { data = dataList }
				local result = Interpreter.execute(code.bytecode, globals, {}, code.constants, code.names)
				TestFramework.assertType(result, "table", "Result should be PyObject list")
				TestFramework.assertEqual(result.__type, "list", "Result should be list")
				TestFramework.assertEqual(#result.__value, 3, "List should have three elements")
				TestFramework.assertEqual(result.__value[1].__value, 1, "First element should be 1")
				TestFramework.assertEqual(result.__value[3].__value, 3, "Last element should be 3")
				TestFramework.assertEqual(globals.x, nil, "Comprehension target should not leak to globals")
			end,
		},
		{
			name = "Compile floor division expression",
			test = function()
				local tokens = Lexer.tokenize("7 // 3")
				local exprAst = Parser.parseExpression(tokens)
				local code = Compiler.compile(exprAst)
				local seenFloorDiv = false
				for _, ins in ipairs(code.bytecode) do
					if ins.opcode == "BINARY_FLOOR_DIVIDE" then
						seenFloorDiv = true
						break
					end
				end
				TestFramework.assertTrue(seenFloorDiv, "Bytecode should include BINARY_FLOOR_DIVIDE")
				local result = Interpreter.execute(code.bytecode, {}, {}, code.constants, code.names)
				TestFramework.assertEqual(result, 2, "7 // 3 should evaluate to 2")
			end,
		},
		{
			name = "Compile matrix multiplication expression",
			test = function()
				local tokens = Lexer.tokenize("left @ right")
				local exprAst = Parser.parseExpression(tokens)
				local code = Compiler.compile(exprAst)
				local sawMatmul = false
				for _, ins in ipairs(code.bytecode) do
					if ins.opcode == "BINARY_MATRIX_MULTIPLY" then
						sawMatmul = true
						break
					end
				end
				TestFramework.assertTrue(sawMatmul, "Bytecode should include BINARY_MATRIX_MULTIPLY")
				local left = Collections.newList({
					Collections.newList({ Base.newInt(1), Base.newInt(2) }),
					Collections.newList({ Base.newInt(3), Base.newInt(4) }),
				})
				local right = Collections.newList({
					Collections.newList({ Base.newInt(5), Base.newInt(6) }),
					Collections.newList({ Base.newInt(7), Base.newInt(8) }),
				})
				local globals = { left = left, right = right }
				local result = Interpreter.execute(code.bytecode, globals, {}, code.constants, code.names)
				TestFramework.assertType(result, "table", "Result should be PyObject list")
				TestFramework.assertEqual(result.__type, "list", "Result should be list")
				TestFramework.assertEqual(#result.__value, 2, "Matrix should have two rows")
				TestFramework.assertEqual(result.__value[1].__value[1].__value, 19, "[0][0] should equal 19")
				TestFramework.assertEqual(result.__value[1].__value[2].__value, 22, "[0][1] should equal 22")
				TestFramework.assertEqual(result.__value[2].__value[1].__value, 43, "[1][0] should equal 43")
				TestFramework.assertEqual(result.__value[2].__value[2].__value, 50, "[1][1] should equal 50")
			end,
		},
	},
}

TestFramework.runSuite(bytecodeTests)

return {}
