--!nocheck
-- PyLua Parser Tests - Phase 2.1 Expression Parser
-- Test the expression parsing functionality

local TestFramework = require('./framework')
local Lexer = require('../src/PyLua/lexer')
local Parser = require('../src/PyLua/parser')

-- Test suite for PyLua Parser
local parserTests: TestFramework.TestSuite = {
    name = "PyLua Parser Tests - Expression Parser",
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
            end
        },
        
        {
            name = "Parse Float Literal",
            test = function()
                local tokens = Lexer.tokenize("3.14")
                local ast = Parser.parse(tokens)
                
                local expr = ast.body[1].value
                TestFramework.assertEqual(expr.type, "Constant", "Should be Constant node")
                TestFramework.assertEqual(expr.value, 3.14, "Value should be 3.14")
            end
        },
        
        {
            name = "Parse String Literal",
            test = function()
                local tokens = Lexer.tokenize('"hello"')
                local ast = Parser.parse(tokens)
                
                local expr = ast.body[1].value
                TestFramework.assertEqual(expr.type, "Constant", "Should be Constant node")
                TestFramework.assertEqual(expr.value, "hello", "Value should be 'hello'")
            end
        },
        
        {
            name = "Parse Boolean Literals",
            test = function()
                local tokens = Lexer.tokenize("True")
                local ast = Parser.parse(tokens)
                
                local expr = ast.body[1].value
                TestFramework.assertEqual(expr.type, "Constant", "Should be Constant node")
                TestFramework.assertEqual(expr.value, true, "Value should be true")
            end
        },
        
        {
            name = "Parse None Literal",
            test = function()
                local tokens = Lexer.tokenize("None")
                local ast = Parser.parse(tokens)
                
                local expr = ast.body[1].value
                TestFramework.assertEqual(expr.type, "Constant", "Should be Constant node")
                TestFramework.assertEqual(expr.value, nil, "Value should be nil")
            end
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
            end
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
            end
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
            end
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
            end
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
            end
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
            end
        },
        
        {
            name = "Parse Complex Expression",
            test = function()
                local tokens = Lexer.tokenize("x + y * 2 - 1")
                local ast = Parser.parse(tokens)
                
                local expr = ast.body[1].value
                TestFramework.assertEqual(expr.type, "BinOp", "Should be BinOp node")
                TestFramework.assertEqual(expr.op, "Sub", "Top level should be Sub")
            end
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
            end
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
            end
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
            end
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
            end
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
            end
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
            end
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
            end
        },
        
        {
            name = "Parse Mixed Statements",
            test = function()
                local tokens = Lexer.tokenize("x = 42\nif x > 0:\n    print(x)")
                local ast = Parser.parse(tokens)
                
                TestFramework.assertEqual(#ast.body, 2, "Should have two statements")
                TestFramework.assertEqual(ast.body[1].type, "Assign", "First should be assignment")
                TestFramework.assertEqual(ast.body[2].type, "If", "Second should be if statement")
            end
        },
    }
}

TestFramework.runSuite(parserTests)

return {}
