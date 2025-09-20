--!strict
-- PyLua Bytecode / Compiler Tests (Phase 4.1 minimal subset)

local TestFramework = require("./framework")
local Lexer = require("../src/PyLua/lexer")
local Parser = require("../src/PyLua/parser")
local Compiler = require("../src/PyLua/compiler")
local instr = require("../src/PyLua/bytecode/instructions")

local function compileSource(src: string)
	local tokens = Lexer.tokenize(src)
	local ast = Parser.parse(tokens)
	return Compiler.compile(ast)
end

local bytecodeTests: TestFramework.TestSuite = {
	name = "Bytecode Compiler Minimal Tests",
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
				local returnAst = { type = "Module", body = { { type = "Return", value = { type = "Constant", value = 5, lineno = 1, col_offset = 0 }, lineno = 1, col_offset = 0 } }, lineno = 1, col_offset = 0 }
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
				local Lexer = require("../src/PyLua/lexer")
				local Parser = require("../src/PyLua/parser")
				local tokens = Lexer.tokenize("b'AB'")
				local exprAst = Parser.parseExpression(tokens)
				local code = Compiler.compile(exprAst)
				-- Execute via interpreter to realize bytes object
				local Interpreter = require("../src/PyLua/vm/interpreter")
				local result = Interpreter.execute(code.bytecode, {}, {}, code.constants, code.names)
				TestFramework.assertType(result, "table", "Result should be PyObject")
				TestFramework.assertEqual(result.__type, "bytes", "Type should be bytes")
				TestFramework.assertEqual(result.__value, "AB", "Bytes content should match")
			end,
		},
	},
}

TestFramework.runSuite(bytecodeTests)

return {}
