--!strict
-- PyLua AST System Tests
-- Phase 1.3 - Test AST node creation and visitor pattern

local TestFramework = require('./framework')
local nodes = require('../src/PyLua/ast/nodes')
local visitor = require('../src/PyLua/ast/visitor')

local astTests = {
    name = "PyLua AST Tests",
    tests = {
        {
            name = "Create base AST node with location info",
            test = function()
                local node = nodes.new_node("Test", 1, 0)
                TestFramework.assertEqual(node.type, "Test", "Node type set")
                TestFramework.assertEqual(node.lineno, 1, "Line number set")
                TestFramework.assertEqual(node.col_offset, 0, "Col offset set")
                TestFramework.assertTrue(node.end_lineno == nil, "End line nil")
                TestFramework.assertTrue(node.end_col_offset == nil, "End col nil")
            end
        },
        {
            name = "Set end location information",
            test = function()
                local node = nodes.new_node("Test", 1, 0)
                nodes.set_end_location(node, 2, 10)
                TestFramework.assertEqual(node.end_lineno, 2, "End line set")
                TestFramework.assertEqual(node.end_col_offset, 10, "End col set")
            end
        },
        {
            name = "Copy location information",
            test = function()
                local from_node = nodes.new_node("From", 5, 10)
                nodes.set_end_location(from_node, 6, 20)
                local to_node = nodes.new_node("To", 1, 0)
                nodes.copy_location(from_node, to_node)
                TestFramework.assertEqual(to_node.lineno, 5, "Copied line")
                TestFramework.assertEqual(to_node.col_offset, 10, "Copied col")
                TestFramework.assertEqual(to_node.end_lineno, 6, "Copied end line")
                TestFramework.assertEqual(to_node.end_col_offset, 20, "Copied end col")
            end
        },
        {
            name = "Create visitor instance",
            test = function()
                local v = visitor.new()
                TestFramework.assertTrue(v ~= nil, "Visitor created")
                TestFramework.assertType(v.visit, "function", "visit exists")
                TestFramework.assertType(v.generic_visit, "function", "generic_visit exists")
            end
        },
        {
            name = "Visit simple node via generic override",
            test = function()
                local v = visitor.new()
                local visited = {}
                function v:generic_visit(node)
                    table.insert(visited, node.type)
                    visitor.generic_visit(self, node)
                    return nil
                end
                v:visit(nodes.new_node("TestNode", 1, 0))
                TestFramework.assertEqual(#visited, 1, "One visited")
                TestFramework.assertEqual(visited[1], "TestNode", "Visited TestNode")
            end
        },
        {
            name = "Dispatch specific visit method",
            test = function()
                local v = visitor.new()
                local called = false
                function v:visit_Constant(node)
                    called = true
                    TestFramework.assertEqual(node.type, "Constant", "Constant node")
                    return nil
                end
                local cn = nodes.new_node("Constant", 1, 0)
                local anyCn = cn :: any
                anyCn.value = 42
                v:visit(cn)
                TestFramework.assertTrue(called, "Specific visit called")
            end
        },
        {
            name = "Create node collector",
            test = function()
                local collector = visitor.new_collector()
                TestFramework.assertTrue(collector ~= nil, "Collector created")
                TestFramework.assertType(collector.collect, "function", "collect exists")
                TestFramework.assertEqual(type(collector.collected), "table", "collected table exists")
            end
        },
        {
            name = "Collect specific node types",
            test = function()
                local collector = visitor.new_collector()
                local testNode = nodes.new_node("TestType", 1, 0)
                local collected = collector:collect(testNode, {"TestType"})
                TestFramework.assertEqual(#collected, 1, "One collected")
                TestFramework.assertEqual(collected[1].type, "TestType", "Correct type collected")
            end
        },
    }
}

TestFramework.runSuite(astTests)

return {}

