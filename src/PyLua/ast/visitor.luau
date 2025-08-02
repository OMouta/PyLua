--!strict
-- PyLua AST Visitor Pattern
-- Phase 1.3 - For AST traversal and manipulation  

local Visitor = {}

local nodes = require('./nodes')
type ASTNode = nodes.ASTNode

-- Base visitor class
export type Visitor = {
    visit: (self: Visitor, node: ASTNode) -> any,
    generic_visit: (self: Visitor, node: ASTNode) -> any,
}

-- Create a new visitor instance
function Visitor.new(): Visitor
    local visitor = {}
    setmetatable(visitor, {__index = Visitor})
    return visitor :: any
end

-- Main visit method - dispatches to specific visit methods
function Visitor:visit(node: ASTNode): any
    local method_name = "visit_" .. node.type
    local method = (self :: any)[method_name]
    
    if method then
        return method(self, node)
    else
        return self:generic_visit(node)
    end
end

-- Generic visit - visits all child nodes
function Visitor:generic_visit(node: ASTNode): any
    -- TODO: Implement generic node traversal in Phase 1.3
    -- This should visit all child nodes of the current node
    return nil
end

return Visitor
