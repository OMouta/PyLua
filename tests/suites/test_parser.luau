--!nocheck
-- PyLua Parser Tests - Phase 2.1 Expression Parser
-- Test the expression parsing functionality

local TestFramework = require("../framework")
local Lexer = require("../../src/PyLua/lexer")
local Parser = require("../../src/PyLua/parser")

-- Test suite for PyLua Parser
local parserTests: TestFramework.TestSuite = {
	name = "PyLua Parser Tests",
	tests = {
		{
			name = "Parse Number Literal",
			test = function()
				local tokens = Lexer.tokenize("42")
				local ast = Parser.parse(tokens)

				TestFramework.assertEqual(ast.type, "Module", "Should parse as Module")
				TestFramework.assertEqual(#ast.body, 1, "Should have one statement")
				TestFramework.assertEqual(ast.body[1].type, "Expr", "Should be expression statement")

				local expr = ast.body[1].value
				TestFramework.assertEqual(expr.type, "Constant", "Should be Constant node")
				TestFramework.assertEqual(expr.value, 42, "Value should be 42")
			end,
		},

		{
			name = "Parse Float Literal",
			test = function()
				local tokens = Lexer.tokenize("3.14")
				local ast = Parser.parse(tokens)

				local expr = ast.body[1].value
				TestFramework.assertEqual(expr.type, "Constant", "Should be Constant node")
				TestFramework.assertEqual(expr.value, 3.14, "Value should be 3.14")
			end,
		},

		{
			name = "Parse String Literal",
			test = function()
				local tokens = Lexer.tokenize('"hello"')
				local ast = Parser.parse(tokens)

				local expr = ast.body[1].value
				TestFramework.assertEqual(expr.type, "Constant", "Should be Constant node")
				TestFramework.assertEqual(expr.value, "hello", "Value should be 'hello'")
			end,
		},

		{
			name = "Parse u-prefixed string normalizes to str",
			test = function()
				local tokens = Lexer.tokenize("u'hello'")
				local ast = Parser.parse(tokens)
				local expr = ast.body[1].value
				TestFramework.assertEqual(expr.type, "Constant", "Should be Constant node")
				TestFramework.assertEqual(expr.value, "hello", "Value should be 'hello'")
				TestFramework.assertEqual(expr.kind, nil, "u prefix should be normalized away")
			end,
		},

		{
			name = "Parse b-prefixed string marks bytes kind",
			test = function()
				local tokens = Lexer.tokenize("b'AB'")
				local ast = Parser.parse(tokens)
				local expr = ast.body[1].value
				TestFramework.assertEqual(expr.type, "Constant", "Should be Constant node")
				TestFramework.assertEqual(expr.value, "AB", "Value should be 'AB'")
				TestFramework.assertEqual(expr.kind, "bytes", "Kind should be bytes")
			end,
		},

		{
			name = "Parse string literal subscript",
			test = function()
				local tokens = Lexer.tokenize('"hi"[0]')
				local ast = Parser.parse(tokens)
				local expr = ast.body[1].value
				TestFramework.assertEqual(expr.type, "Subscript", "Should parse subscript on literal")
				TestFramework.assertEqual(expr.value.type, "Constant", "Base should be constant string")
				TestFramework.assertEqual(expr.value.value, "hi", "String literal should remain 'hi'")
				TestFramework.assertEqual(expr.slice.type, "Constant", "Index should be constant")
				TestFramework.assertEqual(expr.slice.value, 0, "Index value should be 0")
			end,
		},

		{
			name = "Parse Simple F-string",
			test = function()
				local tokens = Lexer.tokenize('f"Hello {name}!"')
				local ast = Parser.parse(tokens)
				local expr = ast.body[1].value
				TestFramework.assertEqual(expr.type, "BinOp", "F-string should become concatenation chain")
				TestFramework.assertEqual(expr.op, "Add", "Top-level op should be Add")
				TestFramework.assertEqual(expr.left.type, "BinOp", "Left branch should combine literal and expression")
				TestFramework.assertEqual(expr.left.op, "Add", "Left branch should also be Add")
				TestFramework.assertEqual(expr.left.left.type, "Constant", "First literal segment should be Constant")
				TestFramework.assertEqual(expr.left.left.value, "Hello ", "Literal should include trailing space")
				TestFramework.assertEqual(expr.left.right.type, "Call", "Expression segment should be wrapped in str()")
				TestFramework.assertEqual(expr.left.right.func.id, "str", "Conversion should use str()")
				TestFramework.assertEqual(expr.left.right.args[1].type, "Name", "Argument should be Name")
				TestFramework.assertEqual(expr.left.right.args[1].id, "name", "Name should be 'name'")
				TestFramework.assertEqual(expr.right.type, "Constant", "Trailing literal should be Constant")
				TestFramework.assertEqual(expr.right.value, "!", "Trailing literal should preserve punctuation")
			end,
		},

		{
			name = "Parse F-string With Format Spec",
			test = function()
				local tokens = Lexer.tokenize('f"{value:.2f}"')
				local ast = Parser.parse(tokens)
				local expr = ast.body[1].value
				TestFramework.assertEqual(expr.type, "Call", "Format spec should produce Call")
				TestFramework.assertEqual(expr.func.type, "Name", "Function should be Name")
				TestFramework.assertEqual(expr.func.id, "format", "Should call built-in format()")
				TestFramework.assertEqual(#expr.args, 2, "format() should receive value and spec")
				TestFramework.assertEqual(expr.args[1].type, "Name", "First argument should be value Name")
				TestFramework.assertEqual(expr.args[1].id, "value", "Value argument should be 'value'")
				TestFramework.assertEqual(expr.args[2].type, "Constant", "Second argument should be Constant spec")
				TestFramework.assertEqual(expr.args[2].value, ".2f", "Format spec literal should match")
			end,
		},

		{
			name = "Parse Boolean Literals",
			test = function()
				local tokens = Lexer.tokenize("True")
				local ast = Parser.parse(tokens)

				local expr = ast.body[1].value
				TestFramework.assertEqual(expr.type, "Constant", "Should be Constant node")
				TestFramework.assertEqual(expr.value, true, "Value should be true")
			end,
		},

		{
			name = "Parse None Literal",
			test = function()
				local tokens = Lexer.tokenize("None")
				local ast = Parser.parse(tokens)

				local expr = ast.body[1].value
				TestFramework.assertEqual(expr.type, "Constant", "Should be Constant node")
				TestFramework.assertEqual(expr.value, nil, "Value should be nil")
			end,
		},

		{
			name = "Parse Variable Name",
			test = function()
				local tokens = Lexer.tokenize("x")
				local ast = Parser.parse(tokens)

				local expr = ast.body[1].value
				TestFramework.assertEqual(expr.type, "Name", "Should be Name node")
				TestFramework.assertEqual(expr.id, "x", "Name should be 'x'")
				TestFramework.assertEqual(expr.ctx, "Load", "Context should be Load")
			end,
		},

		{
			name = "Parse Simple Addition",
			test = function()
				local tokens = Lexer.tokenize("1 + 2")
				local ast = Parser.parse(tokens)

				local expr = ast.body[1].value
				TestFramework.assertEqual(expr.type, "BinOp", "Should be BinOp node")
				TestFramework.assertEqual(expr.op, "Add", "Operator should be Add")
				TestFramework.assertEqual(expr.left.type, "Constant", "Left should be Constant")
				TestFramework.assertEqual(expr.left.value, 1, "Left value should be 1")
				TestFramework.assertEqual(expr.right.type, "Constant", "Right should be Constant")
				TestFramework.assertEqual(expr.right.value, 2, "Right value should be 2")
			end,
		},

		{
			name = "Parse Multiple Operations",
			test = function()
				local tokens = Lexer.tokenize("1 + 2 * 3")
				local ast = Parser.parse(tokens)

				local expr = ast.body[1].value
				TestFramework.assertEqual(expr.type, "BinOp", "Should be BinOp node")
				TestFramework.assertEqual(expr.op, "Add", "Top level should be Add")
				TestFramework.assertEqual(expr.left.value, 1, "Left should be 1")
				TestFramework.assertEqual(expr.right.type, "BinOp", "Right should be BinOp")
				TestFramework.assertEqual(expr.right.op, "Mult", "Right op should be Mult")
			end,
		},

		{
			name = "Parse Floor Division",
			test = function()
				local tokens = Lexer.tokenize("7 // 3")
				local ast = Parser.parse(tokens)
				local expr = ast.body[1].value
				TestFramework.assertEqual(expr.type, "BinOp", "Should be BinOp node")
				TestFramework.assertEqual(expr.op, "FloorDiv", "Operator should be FloorDiv")
			end,
		},

		{
			name = "Parse Matrix Multiply",
			test = function()
				local tokens = Lexer.tokenize("A @ B")
				local ast = Parser.parse(tokens)
				local expr = ast.body[1].value
				TestFramework.assertEqual(expr.type, "BinOp", "Should be BinOp node")
				TestFramework.assertEqual(expr.op, "MatMult", "Operator should be MatMult")
			end,
		},

		{
			name = "Parse Unary Minus",
			test = function()
				local tokens = Lexer.tokenize("-42")
				local ast = Parser.parse(tokens)

				local expr = ast.body[1].value
				TestFramework.assertEqual(expr.type, "UnaryOp", "Should be UnaryOp node")
				TestFramework.assertEqual(expr.op, "USub", "Operator should be USub")
				TestFramework.assertEqual(expr.operand.type, "Constant", "Operand should be Constant")
				TestFramework.assertEqual(expr.operand.value, 42, "Operand value should be 42")
			end,
		},

		{
			name = "Parse Parenthesized Expression",
			test = function()
				local tokens = Lexer.tokenize("(1 + 2) * 3")
				local ast = Parser.parse(tokens)

				local expr = ast.body[1].value
				TestFramework.assertEqual(expr.type, "BinOp", "Should be BinOp node")
				TestFramework.assertEqual(expr.op, "Mult", "Top level should be Mult")
				TestFramework.assertEqual(expr.left.type, "BinOp", "Left should be BinOp")
				TestFramework.assertEqual(expr.left.op, "Add", "Left op should be Add")
			end,
		},

		{
			name = "Parse Comparison",
			test = function()
				local tokens = Lexer.tokenize("x < 5")
				local ast = Parser.parse(tokens)

				local expr = ast.body[1].value
				TestFramework.assertEqual(expr.type, "Compare", "Should be Compare node")
				TestFramework.assertEqual(#expr.ops, 1, "Should have one operator")
				TestFramework.assertEqual(expr.ops[1], "Lt", "Operator should be Lt")
				TestFramework.assertEqual(expr.left.type, "Name", "Left should be Name")
				TestFramework.assertEqual(expr.left.id, "x", "Left name should be x")
			end,
		},

		{
			name = "Parse Complex Expression",
			test = function()
				local tokens = Lexer.tokenize("x + y * 2 - 1")
				local ast = Parser.parse(tokens)

				local expr = ast.body[1].value
				TestFramework.assertEqual(expr.type, "BinOp", "Should be BinOp node")
				TestFramework.assertEqual(expr.op, "Sub", "Top level should be Sub")
			end,
		},

		-- ========== STATEMENT PARSER TESTS ==========

		{
			name = "Parse Assignment Statement",
			test = function()
				local tokens = Lexer.tokenize("x = 42")
				local ast = Parser.parse(tokens)

				TestFramework.assertEqual(ast.type, "Module", "Should parse as Module")
				TestFramework.assertEqual(#ast.body, 1, "Should have one statement")

				local stmt = ast.body[1]
				TestFramework.assertEqual(stmt.type, "Assign", "Should be Assign statement")
				TestFramework.assertEqual(#stmt.targets, 1, "Should have one target")
				TestFramework.assertEqual(stmt.targets[1].type, "Name", "Target should be Name")
				TestFramework.assertEqual(stmt.targets[1].id, "x", "Target name should be 'x'")
				TestFramework.assertEqual(stmt.targets[1].ctx, "Store", "Target context should be Store")
				TestFramework.assertEqual(stmt.value.type, "Constant", "Value should be Constant")
				TestFramework.assertEqual(stmt.value.value, 42, "Value should be 42")
			end,
		},

		{
			name = "Parse Expression Statement",
			test = function()
				local tokens = Lexer.tokenize("print(42)")
				local ast = Parser.parse(tokens)

				local stmt = ast.body[1]
				TestFramework.assertEqual(stmt.type, "Expr", "Should be expression statement")
				TestFramework.assertEqual(stmt.value.type, "Call", "Should be function call")
				TestFramework.assertEqual(stmt.value.func.type, "Name", "Function should be Name")
				TestFramework.assertEqual(stmt.value.func.id, "print", "Function name should be 'print'")
			end,
		},

		{
			name = "Parse If Statement",
			test = function()
				local tokens = Lexer.tokenize("if x < 5:\n    y = 10")
				local ast = Parser.parse(tokens)

				local stmt = ast.body[1]
				TestFramework.assertEqual(stmt.type, "If", "Should be If statement")
				TestFramework.assertEqual(stmt.test.type, "Compare", "Test should be comparison")
				TestFramework.assertEqual(stmt.test.ops[1], "Lt", "Should be less than")
				TestFramework.assertEqual(#stmt.body, 1, "Should have one statement in body")
				TestFramework.assertEqual(stmt.body[1].type, "Assign", "Body should contain assignment")
			end,
		},

		{
			name = "Parse While Statement",
			test = function()
				local tokens = Lexer.tokenize("while x > 0:\n    x = x - 1")
				local ast = Parser.parse(tokens)

				local stmt = ast.body[1]
				TestFramework.assertEqual(stmt.type, "While", "Should be While statement")
				TestFramework.assertEqual(stmt.test.type, "Compare", "Test should be comparison")
				TestFramework.assertEqual(stmt.test.ops[1], "Gt", "Should be greater than")
				TestFramework.assertEqual(#stmt.body, 1, "Should have one statement in body")
			end,
		},

		{
			name = "Parse For Statement",
			test = function()
				local tokens = Lexer.tokenize("for i in range(10):\n    print(i)")
				local ast = Parser.parse(tokens)

				local stmt = ast.body[1]
				TestFramework.assertEqual(stmt.type, "For", "Should be For statement")
				TestFramework.assertEqual(stmt.target.type, "Name", "Target should be Name")
				TestFramework.assertEqual(stmt.target.id, "i", "Target should be 'i'")
				TestFramework.assertEqual(stmt.target.ctx, "Store", "Target context should be Store")
				TestFramework.assertEqual(stmt.iter.type, "Call", "Iterator should be function call")
				TestFramework.assertEqual(stmt.iter.func.id, "range", "Iterator function should be 'range'")
				TestFramework.assertEqual(#stmt.body, 1, "Should have one statement in body")
			end,
		},

		{
			name = "Parse Function Definition",
			test = function()
				local tokens = Lexer.tokenize("def hello():\n    return 42")
				local ast = Parser.parse(tokens)

				local stmt = ast.body[1]
				TestFramework.assertEqual(stmt.type, "FunctionDef", "Should be FunctionDef statement")
				TestFramework.assertEqual(stmt.name, "hello", "Function name should be 'hello'")
				TestFramework.assertEqual(#stmt.args.args, 0, "Should have no arguments")
				TestFramework.assertEqual(#stmt.body, 1, "Should have one statement in body")
			end,
		},

		{
			name = "Parse Multiple Statements",
			test = function()
				local tokens = Lexer.tokenize("x = 1\ny = 2\nz = x + y")
				local ast = Parser.parse(tokens)

				TestFramework.assertEqual(#ast.body, 3, "Should have three statements")
				TestFramework.assertEqual(ast.body[1].type, "Assign", "First should be assignment")
				TestFramework.assertEqual(ast.body[2].type, "Assign", "Second should be assignment")
				TestFramework.assertEqual(ast.body[3].type, "Assign", "Third should be assignment")

				TestFramework.assertEqual(ast.body[1].targets[1].id, "x", "First assigns to x")
				TestFramework.assertEqual(ast.body[2].targets[1].id, "y", "Second assigns to y")
				TestFramework.assertEqual(ast.body[3].targets[1].id, "z", "Third assigns to z")
			end,
		},

		{
			name = "Parse Mixed Statements",
			test = function()
				local tokens = Lexer.tokenize("x = 42\nif x > 0:\n    print(x)")
				local ast = Parser.parse(tokens)

				TestFramework.assertEqual(#ast.body, 2, "Should have two statements")
				TestFramework.assertEqual(ast.body[1].type, "Assign", "First should be assignment")
				TestFramework.assertEqual(ast.body[2].type, "If", "Second should be if statement")
			end,
		},
		-- ========== ADVANCED PARSING (2.3) TESTS ==========
		{
			name = "Parse List Literal",
			test = function()
				local tokens = Lexer.tokenize("[1, 2, x]")
				local ast = Parser.parse(tokens)
				local expr = ast.body[1].value
				TestFramework.assertEqual(expr.type, "List", "Should be List node")
				TestFramework.assertEqual(#expr.elts, 3, "List should have 3 elements")
				TestFramework.assertEqual(expr.elts[1].value, 1, "First element 1")
			end,
		},
		{
			name = "Parse List Comprehension",
			test = function()
				local tokens = Lexer.tokenize("[x for x in data]")
				local ast = Parser.parse(tokens)
				local expr = ast.body[1].value
				TestFramework.assertEqual(expr.type, "ListComp", "Should be ListComp node")
				TestFramework.assertEqual(expr.elt.type, "Name", "Element should be Name")
				TestFramework.assertEqual(#expr.generators, 1, "Should have one generator")
				local gen = expr.generators[1]
				TestFramework.assertEqual(gen.target.type, "Name", "Target should be Name")
				TestFramework.assertEqual(gen.target.ctx, "Store", "Target context should be Store")
				TestFramework.assertEqual(gen.iter.type, "Name", "Iter should be Name")
				TestFramework.assertEqual(#gen.ifs, 0, "No filters")
			end,
		},
		{
			name = "Parse List Comprehension With Filter",
			test = function()
				local tokens = Lexer.tokenize("[x for x in data if x]")
				local ast = Parser.parse(tokens)
				local expr = ast.body[1].value
				TestFramework.assertEqual(expr.type, "ListComp", "Should be ListComp node")
				local gen = expr.generators[1]
				TestFramework.assertEqual(#gen.ifs, 1, "Should have one filter")
				TestFramework.assertEqual(gen.ifs[1].type, "Name", "Filter should be Name expression")
			end,
		},
		{
			name = "Parse Dict Literal",
			test = function()
				local tokens = Lexer.tokenize('{"a": 1, "b": x}')
				local ast = Parser.parse(tokens)
				local expr = ast.body[1].value
				TestFramework.assertEqual(expr.type, "Dict", "Should be Dict node")
				TestFramework.assertEqual(#expr.keys, 2, "Two keys")
				TestFramework.assertEqual(expr.values[1].value, 1, "First value 1")
			end,
		},
		{
			name = "Parse Empty Dict Literal",
			test = function()
				local tokens = Lexer.tokenize("{}")
				local ast = Parser.parse(tokens)
				local expr = ast.body[1].value
				TestFramework.assertEqual(expr.type, "Dict", "Should be Dict node")
				TestFramework.assertEqual(#expr.keys, 0, "No keys")
			end,
		},
		{
			name = "Parse Set Literal",
			test = function()
				local tokens = Lexer.tokenize("{1, 2, 3}")
				local ast = Parser.parse(tokens)
				local expr = ast.body[1].value
				TestFramework.assertEqual(expr.type, "Set", "Should be Set node")
				TestFramework.assertEqual(#expr.elts, 3, "3 elements")
			end,
		},
		{
			name = "Parse Tuple Literal",
			test = function()
				local tokens = Lexer.tokenize("(1, 2, 3)")
				local ast = Parser.parse(tokens)
				local expr = ast.body[1].value
				TestFramework.assertEqual(expr.type, "Tuple", "Should be Tuple node")
				TestFramework.assertEqual(#expr.elts, 3, "3 elements")
			end,
		},
		{
			name = "Parse Indexing",
			test = function()
				local tokens = Lexer.tokenize("x[0]")
				local ast = Parser.parse(tokens)
				local expr = ast.body[1].value
				TestFramework.assertEqual(expr.type, "Subscript", "Should be Subscript node")
				TestFramework.assertEqual(expr.value.type, "Name", "Base name")
			end,
		},
		{
			name = "Parse Attribute Access",
			test = function()
				local tokens = Lexer.tokenize("obj.field")
				local ast = Parser.parse(tokens)
				local expr = ast.body[1].value
				TestFramework.assertEqual(expr.type, "Attribute", "Should be Attribute node")
				TestFramework.assertEqual(expr.attr, "field", "Attr name")
			end,
		},
		{
			name = "Parse Call With Args And Keywords",
			test = function()
				local tokens = Lexer.tokenize("func(1, 2, x=3, y=foo)")
				local ast = Parser.parse(tokens)
				local expr = ast.body[1].value
				TestFramework.assertEqual(expr.type, "Call", "Should be Call")
				TestFramework.assertEqual(#expr.args, 2, "Two positional args")
				TestFramework.assertEqual(#expr.keywords, 2, "Two keyword args")
				TestFramework.assertEqual(expr.keywords[1].arg, "x", "First kw name x")
			end,
		},
		{
			name = "Parse Lambda Expression",
			test = function()
				local tokens = Lexer.tokenize("lambda x, y=1: x + y")
				local ast = Parser.parse(tokens)
				local expr = ast.body[1].value
				TestFramework.assertEqual(expr.type, "Lambda", "Should be Lambda node")
				TestFramework.assertEqual(#expr.args.args, 2, "Lambda should have two parameters")
				TestFramework.assertEqual(#expr.args.defaults, 1, "Lambda should capture defaults")
				TestFramework.assertEqual(expr.body.type, "BinOp", "Lambda body should be BinOp")
			end,
		},
		{
			name = "Parse Lambda As Binary Operand",
			test = function()
				local tokens = Lexer.tokenize("a + lambda x: x")
				local ast = Parser.parse(tokens)
				local expr = ast.body[1].value
				TestFramework.assertEqual(expr.type, "BinOp", "Top level should be BinOp")
				TestFramework.assertEqual(expr.op, "Add", "Operator should be Add")
				TestFramework.assertEqual(expr.right.type, "Lambda", "Right side should be Lambda expression")
			end,
		},
		{
			name = "Parse Nested Lambda Body",
			test = function()
				local tokens = Lexer.tokenize("lambda x: lambda y: x + y")
				local ast = Parser.parse(tokens)
				local expr = ast.body[1].value
				TestFramework.assertEqual(expr.type, "Lambda", "Outer expression should be Lambda")
				TestFramework.assertEqual(expr.body.type, "Lambda", "Body should be Lambda for nested form")
			end,
		},
		{
			name = "Parse Chained Postfix",
			test = function()
				local tokens = Lexer.tokenize("obj.method(1).attr[2]")
				local ast = Parser.parse(tokens)
				local expr = ast.body[1].value
				TestFramework.assertEqual(expr.type, "Subscript", "Ends with subscript")
				TestFramework.assertEqual(expr.value.type, "Attribute" or "Call", "Previous node exists")
			end,
		},
		-- Phase 2.4 enhancements
		{
			name = "Parse Boolean And/Or Chain",
			test = function()
				local tokens = Lexer.tokenize("a and b or c")
				local ast = Parser.parse(tokens)
				local expr = ast.body[1].value
				TestFramework.assertEqual(expr.type, "BoolOp", "Top should be BoolOp")
			end,
		},
		{
			name = "Parse Chained Comparisons",
			test = function()
				local tokens = Lexer.tokenize("a < b < c")
				local ast = Parser.parse(tokens)
				local expr = ast.body[1].value
				TestFramework.assertEqual(expr.type, "Compare", "Compare node")
				TestFramework.assertEqual(#expr.ops, 2, "Two ops")
			end,
		},
		{
			name = "Parse Augmented Assignment",
			test = function()
				local tokens = Lexer.tokenize("x += 1")
				local ast = Parser.parse(tokens)
				local stmt = ast.body[1]
				TestFramework.assertEqual(stmt.type, "AugAssign", "AugAssign node")
				TestFramework.assertEqual(stmt.op, "Add", "Add op")
			end,
		},
		{
			name = "Parse Starred List Literal",
			test = function()
				local tokens = Lexer.tokenize("[*a, b]")
				local ast = Parser.parse(tokens)
				local expr = ast.body[1].value
				TestFramework.assertEqual(expr.type, "List", "List node")
				TestFramework.assertEqual(expr.elts[1].type, "Starred", "First element starred")
			end,
		},
		{
			name = "Parse Dict Unpacking",
			test = function()
				local tokens = Lexer.tokenize('{**d1, "k": v}')
				local ast = Parser.parse(tokens)
				local expr = ast.body[1].value
				TestFramework.assertEqual(expr.type, "Dict", "Dict node")
				TestFramework.assertEqual(expr.keys[1].type, "DictUnpack", "First key is DictUnpack sentinel")
				TestFramework.assertEqual(expr.values[1].type, "Name", "Value for unpack entry is expression")
			end,
		},
		{
			name = "Parse Starred Call Args",
			test = function()
				local tokens = Lexer.tokenize("f(*a, **k)")
				local ast = Parser.parse(tokens)
				local expr = ast.body[1].value
				TestFramework.assertEqual(expr.type, "Call", "Call node")
				TestFramework.assertEqual(expr.args[1].type, "Starred", "Starred arg")
				TestFramework.assertEqual(expr.keywords[1].arg, nil, "Keyword unpack")
			end,
		},
		{
			name = "Parse Compound Comparison Keywords",
			test = function()
				local tokens = Lexer.tokenize("a is not b")
				local ast = Parser.parse(tokens)
				local expr = ast.body[1].value
				TestFramework.assertEqual(expr.type, "Compare", "Compare node")
				TestFramework.assertEqual(expr.ops[1], "IsNot", "IsNot op")
			end,
		},
		{
			name = "Parse Not In Comparison",
			test = function()
				local tokens = Lexer.tokenize("x not in y")
				local ast = Parser.parse(tokens)
				local expr = ast.body[1].value
				TestFramework.assertEqual(expr.type, "Compare", "Compare node")
				TestFramework.assertEqual(expr.ops[1], "NotIn", "NotIn op")
			end,
		},
		{
			name = "Parse Attribute Assignment Target",
			test = function()
				local tokens = Lexer.tokenize("obj.attr = 1")
				local ast = Parser.parse(tokens)
				local stmt = ast.body[1]
				TestFramework.assertEqual(stmt.type, "Assign", "Assign node")
				TestFramework.assertEqual(stmt.targets[1].type, "Attribute", "Attribute target")
				TestFramework.assertEqual(stmt.targets[1].ctx, "Store", "Store context")
			end,
		},
		{
			name = "Parse Subscript Assignment Target",
			test = function()
				local tokens = Lexer.tokenize("arr[0] = x")
				local ast = Parser.parse(tokens)
				local stmt = ast.body[1]
				TestFramework.assertEqual(stmt.type, "Assign", "Assign node")
				TestFramework.assertEqual(stmt.targets[1].type, "Subscript", "Subscript target")
				TestFramework.assertEqual(stmt.targets[1].ctx, "Store", "Store context")
			end,
		},
	},
}

TestFramework.runSuite(parserTests)

return {}
