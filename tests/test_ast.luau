--!strict
-- PyLua AST System Tests
-- Phase 1.3 - Test AST node creation and visitor pattern

local test = require('./framework')
local nodes = require('../src/PyLua/ast/nodes')
local visitor = require('../src/PyLua/ast/visitor')

-- ========== NODE CREATION TESTS ==========

local nodeCreationTests = {
    {
        name = "should create base AST nodes with location info",
        test = function()
            local node = nodes.new_node("Test", 1, 0)
            
            test.assert(node.type == "Test", "Node type should be set")
            test.assert(node.lineno == 1, "Line number should be set")
            test.assert(node.col_offset == 0, "Column offset should be set")
            test.assert(node.end_lineno == nil, "End line should be nil initially")
            test.assert(node.end_col_offset == nil, "End column should be nil initially")
        end
    },
    
    {
        name = "should set end location information",
        test = function()
            local node = nodes.new_node("Test", 1, 0)
            nodes.set_end_location(node, 2, 10)
            
            test.assert(node.end_lineno == 2, "End line number should be set")
            test.assert(node.end_col_offset == 10, "End column offset should be set")
        end
    },
    
    {
        name = "should copy location information between nodes",
        test = function()
            local from_node = nodes.new_node("From", 5, 10)
            nodes.set_end_location(from_node, 6, 20)
            
            local to_node = nodes.new_node("To", 1, 0)
            nodes.copy_location(from_node, to_node)
            
            test.assert(to_node.lineno == 5, "Line number should be copied")
            test.assert(to_node.col_offset == 10, "Column offset should be copied")
            test.assert(to_node.end_lineno == 6, "End line number should be copied")
            test.assert(to_node.end_col_offset == 20, "End column offset should be copied")
        end
    }
}

-- ========== VISITOR PATTERN TESTS ==========

local visitorTests = {
    {
        name = "should create visitor instances",
        test = function()
            local v = visitor.new()
            
            test.assert(v ~= nil, "Visitor should be created")
            test.assertType(v.visit, "function", "Visitor should have visit method")
            test.assertType(v.generic_visit, "function", "Visitor should have generic_visit method")
        end
    },
    
    {
        name = "should visit simple nodes",
        test = function()
            local v = visitor.new()
            local visited_nodes = {}
            
            -- Override generic_visit to track visited nodes
            function v:generic_visit(node)
                table.insert(visited_nodes, node.type)
                visitor.generic_visit(self, node)
                return nil
            end
            
            local simple_node = nodes.new_node("TestNode", 1, 0)
            v:visit(simple_node)
            
            test.assert(#visited_nodes == 1, "Should visit one node")
            test.assert(visited_nodes[1] == "TestNode", "Should visit TestNode")
        end
    },
    
    {
        name = "should dispatch to specific visit methods",
        test = function()
            local v = visitor.new()
            local visited_constant = false
            
            -- Add specific visitor method
            function v:visit_Constant(node)
                visited_constant = true
                test.assert(node.type == "Constant", "Should receive Constant node")
                return nil
            end
            
            local constant_node = nodes.new_node("Constant", 1, 0)
            -- Cast to any to allow dynamic property assignment for testing
            local any_node = constant_node :: any
            any_node.value = 42
            
            v:visit(constant_node)
            
            test.assert(visited_constant, "Should call specific visit method")
        end
    }
}

-- ========== NODE COLLECTOR TESTS ==========

local collectorTests = {
    {
        name = "should create node collectors",
        test = function()
            local collector = visitor.new_collector()
            
            test.assert(collector ~= nil, "Collector should be created")
            test.assertType(collector.collect, "function", "Collector should have collect method")
            test.assert(type(collector.collected) == "table", "Collector should have collected array")
        end
    },
    
    {
        name = "should collect nodes of specific types",
        test = function()
            local collector = visitor.new_collector()
            
            -- Create a simple test node
            local test_node = nodes.new_node("TestType", 1, 0)
            
            local collected = collector:collect(test_node, {"TestType"})
            
            test.assert(#collected == 1, "Should collect one node")
            test.assert(collected[1].type == "TestType", "Should collect TestType node")
        end
    }
}

-- ========== RUN ALL TESTS ==========

local function runTestSuite(suiteName: string, tests: {{name: string, test: () -> ()}})
    print("\n=== " .. suiteName .. " ===")
    
    for _, testCase in ipairs(tests) do
        print("\nRunning: " .. testCase.name)
        
        local success = pcall(testCase.test)
        if not success then
            print("✗ Test failed")
        end
    end
end

print("Running AST System Tests...")

runTestSuite("Node Creation Tests", nodeCreationTests)
runTestSuite("Visitor Pattern Tests", visitorTests)
runTestSuite("Node Collector Tests", collectorTests)

test.printSummary()
