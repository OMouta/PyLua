--!strict
-- PyLua Lexer Tests
-- Test the Python tokenization functionality

local TestFramework = require("./framework")
local Lexer = require("../src/PyLua/lexer")

-- Test suite for PyLua Lexer
local lexerTests: TestFramework.TestSuite = {
	name = "PyLua Lexer Tests",
	tests = {
		{
			name = "Simple Number Tokenization",
			test = function()
				local tokens = Lexer.tokenize("42")
				TestFramework.assertEqual(#tokens, 2, "Should have 2 tokens (number + endmarker)")
				TestFramework.assertEqual(tokens[1].type, "NUMBER", "First token should be NUMBER")
				TestFramework.assertEqual(tokens[1].value, "42", "Number value should be '42'")
				TestFramework.assertEqual(tokens[2].type, "ENDMARKER", "Second token should be ENDMARKER")
			end,
		},

		{
			name = "Float Number Tokenization",
			test = function()
				local tokens = Lexer.tokenize("3.14")
				TestFramework.assertEqual(tokens[1].type, "NUMBER", "Should tokenize float")
				TestFramework.assertEqual(tokens[1].value, "3.14", "Float value should be correct")
			end,
		},

		{
			name = "Scientific Notation",
			test = function()
				local tokens = Lexer.tokenize("1e5")
				TestFramework.assertEqual(tokens[1].type, "NUMBER", "Should tokenize scientific notation")
				TestFramework.assertEqual(tokens[1].value, "1e5", "Scientific notation value should be correct")
			end,
		},

		{
			name = "Binary Number",
			test = function()
				local tokens = Lexer.tokenize("0b1010")
				TestFramework.assertEqual(tokens[1].type, "NUMBER", "Should tokenize binary number")
				TestFramework.assertEqual(tokens[1].value, "0b1010", "Binary value should be correct")
			end,
		},

		{
			name = "Hex Number",
			test = function()
				local tokens = Lexer.tokenize("0xFF")
				TestFramework.assertEqual(tokens[1].type, "NUMBER", "Should tokenize hex number")
				TestFramework.assertEqual(tokens[1].value, "0xFF", "Hex value should be correct")
			end,
		},

		{
			name = "String Tokenization",
			test = function()
				local tokens = Lexer.tokenize('"hello"')
				TestFramework.assertEqual(tokens[1].type, "STRING", "Should tokenize string")
				TestFramework.assertEqual(tokens[1].value, '"hello"', "String value should include quotes")
			end,
		},

		{
			name = "Single Quote String",
			test = function()
				local tokens = Lexer.tokenize("'world'")
				TestFramework.assertEqual(tokens[1].type, "STRING", "Should tokenize single quote string")
				TestFramework.assertEqual(tokens[1].value, "'world'", "String value should include quotes")
			end,
		},

		{
			name = "Triple Quote String",
			test = function()
				local tokens = Lexer.tokenize('"""multi\nline"""')
				TestFramework.assertEqual(tokens[1].type, "STRING", "Should tokenize triple quote string")
				TestFramework.assertTrue(tokens[1].value:find('"""') ~= nil, "Should contain triple quotes")
			end,
		},

		{
			name = "Identifier Tokenization",
			test = function()
				local tokens = Lexer.tokenize("variable_name")
				TestFramework.assertEqual(tokens[1].type, "NAME", "Should tokenize identifier")
				TestFramework.assertEqual(tokens[1].value, "variable_name", "Identifier value should be correct")
			end,
		},

		{
			name = "Keyword Tokenization",
			test = function()
				local tokens = Lexer.tokenize("if elif else")
				TestFramework.assertEqual(tokens[1].type, "IF", "Should tokenize 'if' keyword")
				TestFramework.assertEqual(tokens[2].type, "ELIF", "Should tokenize 'elif' keyword")
				TestFramework.assertEqual(tokens[3].type, "ELSE", "Should tokenize 'else' keyword")
			end,
		},

		{
			name = "Boolean Keywords",
			test = function()
				local tokens = Lexer.tokenize("True False None")
				TestFramework.assertEqual(tokens[1].type, "TRUE", "Should tokenize True")
				TestFramework.assertEqual(tokens[2].type, "FALSE", "Should tokenize False")
				TestFramework.assertEqual(tokens[3].type, "NONE", "Should tokenize None")
			end,
		},

		{
			name = "Operators",
			test = function()
				local tokens = Lexer.tokenize("+ - * / % ** //")
				TestFramework.assertEqual(tokens[1].type, "PLUS", "Should tokenize +")
				TestFramework.assertEqual(tokens[2].type, "MINUS", "Should tokenize -")
				TestFramework.assertEqual(tokens[3].type, "STAR", "Should tokenize *")
				TestFramework.assertEqual(tokens[4].type, "SLASH", "Should tokenize /")
				TestFramework.assertEqual(tokens[5].type, "PERCENT", "Should tokenize %")
				TestFramework.assertEqual(tokens[6].type, "DOUBLESTAR", "Should tokenize **")
				TestFramework.assertEqual(tokens[7].type, "DOUBLESLASH", "Should tokenize //")
			end,
		},

		{
			name = "Comparison Operators",
			test = function()
				local tokens = Lexer.tokenize("== != < > <= >=")
				TestFramework.assertEqual(tokens[1].type, "EQEQUAL", "Should tokenize ==")
				TestFramework.assertEqual(tokens[2].type, "NOTEQUAL", "Should tokenize !=")
				TestFramework.assertEqual(tokens[3].type, "LESS", "Should tokenize <")
				TestFramework.assertEqual(tokens[4].type, "GREATER", "Should tokenize >")
				TestFramework.assertEqual(tokens[5].type, "LESSEQUAL", "Should tokenize <=")
				TestFramework.assertEqual(tokens[6].type, "GREATEREQUAL", "Should tokenize >=")
			end,
		},

		{
			name = "Delimiters",
			test = function()
				local tokens = Lexer.tokenize("()[]{},:;.")
				TestFramework.assertEqual(tokens[1].type, "LPAR", "Should tokenize (")
				TestFramework.assertEqual(tokens[2].type, "RPAR", "Should tokenize )")
				TestFramework.assertEqual(tokens[3].type, "LSQB", "Should tokenize [")
				TestFramework.assertEqual(tokens[4].type, "RSQB", "Should tokenize ]")
				TestFramework.assertEqual(tokens[5].type, "LBRACE", "Should tokenize {")
				TestFramework.assertEqual(tokens[6].type, "RBRACE", "Should tokenize }")
				TestFramework.assertEqual(tokens[7].type, "COMMA", "Should tokenize ,")
				TestFramework.assertEqual(tokens[8].type, "COLON", "Should tokenize :")
				TestFramework.assertEqual(tokens[9].type, "SEMICOLON", "Should tokenize ;")
				TestFramework.assertEqual(tokens[10].type, "DOT", "Should tokenize .")
			end,
		},

		{
			name = "Assignment",
			test = function()
				local tokens = Lexer.tokenize("x = 42")
				TestFramework.assertEqual(tokens[1].type, "NAME", "Should tokenize variable name")
				TestFramework.assertEqual(tokens[2].type, "EQUAL", "Should tokenize =")
				TestFramework.assertEqual(tokens[3].type, "NUMBER", "Should tokenize number")
			end,
		},

		{
			name = "Newlines",
			test = function()
				local tokens = Lexer.tokenize("a\nb")
				TestFramework.assertEqual(tokens[1].type, "NAME", "First token should be NAME")
				TestFramework.assertEqual(tokens[2].type, "NEWLINE", "Should tokenize newline")
				TestFramework.assertEqual(tokens[3].type, "NAME", "Third token should be NAME")
			end,
		},

		{
			name = "Complex Expression",
			test = function()
				local tokens = Lexer.tokenize("result = (x + y) * 2")
				TestFramework.assertEqual(tokens[1].type, "NAME", "Should start with identifier")
				TestFramework.assertEqual(tokens[2].type, "EQUAL", "Should have assignment")
				TestFramework.assertEqual(tokens[3].type, "LPAR", "Should have opening paren")
				-- Test basic structure without checking every token
				TestFramework.assertTrue(#tokens > 8, "Should have multiple tokens for complex expression")
			end,
		},

		{
			name = "Token Positions",
			test = function()
				local tokens = Lexer.tokenize("abc")
				TestFramework.assertEqual(tokens[1].line, 1, "Should be on line 1")
				TestFramework.assertEqual(tokens[1].column, 1, "Should start at column 1")
				TestFramework.assertEqual(tokens[1].endColumn, 3, "Should end at column 3")
			end,
		},
	},
}

TestFramework.runSuite(lexerTests)

return {}
