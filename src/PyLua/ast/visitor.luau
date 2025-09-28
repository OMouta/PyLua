local Visitor = {}

local nodes = require("./nodes")
type ASTNode = nodes.ASTNode
type AnyNode = nodes.AnyNode
type AnyStmt = nodes.AnyStmt
type AnyExpr = nodes.AnyExpr

-- Base visitor class for AST traversal
export type Visitor = {
	visit: (self: Visitor, node: ASTNode) -> any,
	generic_visit: (self: Visitor, node: ASTNode) -> any,

	-- Statement visitors
	visit_Module: ((self: Visitor, node: nodes.Module) -> any)?,
	visit_Assign: ((self: Visitor, node: nodes.Assign) -> any)?,
	visit_AugAssign: ((self: Visitor, node: nodes.AugAssign) -> any)?,
	visit_Expr: ((self: Visitor, node: nodes.ExprStmt) -> any)?,
	visit_If: ((self: Visitor, node: nodes.If) -> any)?,
	visit_While: ((self: Visitor, node: nodes.While) -> any)?,
	visit_For: ((self: Visitor, node: nodes.For) -> any)?,
	visit_FunctionDef: ((self: Visitor, node: nodes.FunctionDef) -> any)?,
	visit_ClassDef: ((self: Visitor, node: nodes.ClassDef) -> any)?,
	visit_Return: ((self: Visitor, node: nodes.Return) -> any)?,
	visit_Break: ((self: Visitor, node: nodes.Break) -> any)?,
	visit_Continue: ((self: Visitor, node: nodes.Continue) -> any)?,
	visit_Pass: ((self: Visitor, node: nodes.Pass) -> any)?,

	-- Expression visitors
	visit_BinOp: ((self: Visitor, node: nodes.BinOpNode) -> any)?,
	visit_UnaryOp: ((self: Visitor, node: nodes.UnaryOpNode) -> any)?,
	visit_BoolOp: ((self: Visitor, node: nodes.BoolOpNode) -> any)?,
	visit_Compare: ((self: Visitor, node: nodes.Compare) -> any)?,
	visit_Call: ((self: Visitor, node: nodes.Call) -> any)?,
	visit_Attribute: ((self: Visitor, node: nodes.Attribute) -> any)?,
	visit_Subscript: ((self: Visitor, node: nodes.Subscript) -> any)?,
	visit_Name: ((self: Visitor, node: nodes.Name) -> any)?,
	visit_Constant: ((self: Visitor, node: nodes.Constant) -> any)?,
	visit_List: ((self: Visitor, node: nodes.List) -> any)?,
	visit_Tuple: ((self: Visitor, node: nodes.Tuple) -> any)?,
	visit_Dict: ((self: Visitor, node: nodes.Dict) -> any)?,
	visit_Set: ((self: Visitor, node: nodes.Set) -> any)?,
}

-- Create a new visitor instance
function Visitor.new(): Visitor
	local visitor = {}
	setmetatable(visitor, { __index = Visitor })
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

-- Generic visit - recursively visits all child nodes
function Visitor:generic_visit(node: ASTNode): any
	local node_type = node.type

	-- Module
	if node_type == "Module" then
		local module_node = node :: nodes.Module
		for _, stmt in ipairs(module_node.body) do
			self:visit(stmt)
		end

	-- Statements
	elseif node_type == "Assign" then
		local assign_node = node :: nodes.Assign
		for _, target in ipairs(assign_node.targets) do
			self:visit(target)
		end
		self:visit(assign_node.value)
	elseif node_type == "AugAssign" then
		local aug_assign_node = node :: nodes.AugAssign
		self:visit(aug_assign_node.target)
		self:visit(aug_assign_node.value)
	elseif node_type == "Expr" then
		local expr_stmt_node = node :: nodes.ExprStmt
		self:visit(expr_stmt_node.value)
	elseif node_type == "If" then
		local if_node = node :: nodes.If
		self:visit(if_node.test)
		for _, stmt in ipairs(if_node.body) do
			self:visit(stmt)
		end
		for _, stmt in ipairs(if_node.orelse) do
			self:visit(stmt)
		end
	elseif node_type == "While" then
		local while_node = node :: nodes.While
		self:visit(while_node.test)
		for _, stmt in ipairs(while_node.body) do
			self:visit(stmt)
		end
		for _, stmt in ipairs(while_node.orelse) do
			self:visit(stmt)
		end
	elseif node_type == "For" then
		local for_node = node :: nodes.For
		self:visit(for_node.target)
		self:visit(for_node.iter)
		for _, stmt in ipairs(for_node.body) do
			self:visit(stmt)
		end
		for _, stmt in ipairs(for_node.orelse) do
			self:visit(stmt)
		end
	elseif node_type == "FunctionDef" then
		local func_node = node :: nodes.FunctionDef
		-- Visit arguments
		local args = func_node.args
		for _, arg in ipairs(args.posonlyargs) do
			if arg.annotation then
				self:visit(arg.annotation)
			end
		end
		for _, arg in ipairs(args.args) do
			if arg.annotation then
				self:visit(arg.annotation)
			end
		end
		if args.vararg and args.vararg.annotation then
			self:visit(args.vararg.annotation)
		end
		for _, arg in ipairs(args.kwonlyargs) do
			if arg.annotation then
				self:visit(arg.annotation)
			end
		end
		if args.kwarg and args.kwarg.annotation then
			self:visit(args.kwarg.annotation)
		end
		for _, default in ipairs(args.defaults) do
			self:visit(default)
		end
		for _, default in ipairs(args.kw_defaults) do
			if default then
				self:visit(default)
			end
		end

		-- Visit decorators
		for _, decorator in ipairs(func_node.decorator_list) do
			self:visit(decorator)
		end

		-- Visit return annotation
		if func_node.returns then
			self:visit(func_node.returns)
		end

		-- Visit body
		for _, stmt in ipairs(func_node.body) do
			self:visit(stmt)
		end
	elseif node_type == "ClassDef" then
		local class_node = node :: nodes.ClassDef
		for _, base in ipairs(class_node.bases) do
			self:visit(base)
		end
		for _, keyword in ipairs(class_node.keywords) do
			self:visit(keyword.value)
		end
		for _, decorator in ipairs(class_node.decorator_list) do
			self:visit(decorator)
		end
		for _, stmt in ipairs(class_node.body) do
			self:visit(stmt)
		end
	elseif node_type == "Return" then
		local return_node = node :: nodes.Return
		if return_node.value then
			self:visit(return_node.value)
		end

	-- Break, Continue, Pass have no child nodes

	-- Expressions
	elseif node_type == "BinOp" then
		local binop_node = node :: nodes.BinOpNode
		self:visit(binop_node.left)
		self:visit(binop_node.right)
	elseif node_type == "UnaryOp" then
		local unaryop_node = node :: nodes.UnaryOpNode
		self:visit(unaryop_node.operand)
	elseif node_type == "BoolOp" then
		local boolop_node = node :: nodes.BoolOpNode
		for _, value in ipairs(boolop_node.values) do
			self:visit(value)
		end
	elseif node_type == "Compare" then
		local compare_node = node :: nodes.Compare
		self:visit(compare_node.left)
		for _, comparator in ipairs(compare_node.comparators) do
			self:visit(comparator)
		end
	elseif node_type == "Call" then
		local call_node = node :: nodes.Call
		self:visit(call_node.func)
		for _, arg in ipairs(call_node.args) do
			self:visit(arg)
		end
		for _, keyword in ipairs(call_node.keywords) do
			self:visit(keyword.value)
		end
	elseif node_type == "Attribute" then
		local attr_node = node :: nodes.Attribute
		self:visit(attr_node.value)
	elseif node_type == "Subscript" then
		local subscript_node = node :: nodes.Subscript
		self:visit(subscript_node.value)
		self:visit(subscript_node.slice)
	elseif node_type == "List" then
		local list_node = node :: nodes.List
		for _, elt in ipairs(list_node.elts) do
			self:visit(elt)
		end
	elseif node_type == "Tuple" then
		local tuple_node = node :: nodes.Tuple
		for _, elt in ipairs(tuple_node.elts) do
			self:visit(elt)
		end
	elseif node_type == "Dict" then
		local dict_node = node :: nodes.Dict
		for i, key in ipairs(dict_node.keys) do
			if key then -- Can be nil for ** unpacking
				self:visit(key)
			end
			self:visit(dict_node.values[i])
		end
	elseif node_type == "Set" then
		local set_node = node :: nodes.Set
		for _, elt in ipairs(set_node.elts) do
			self:visit(elt)
		end

		-- Name and Constant have no child nodes
	end

	return nil
end

-- UTILITY VISITORS
-- Node transformer - creates modified copies of AST nodes
export type NodeTransformer = Visitor & {
	transform: (self: NodeTransformer, node: ASTNode) -> ASTNode,
}

function Visitor.new_transformer(): NodeTransformer
	local transformer = Visitor.new() :: any

	-- Override visit to transform nodes
	function transformer:transform(node: ASTNode): ASTNode
		return self:visit(node) or node
	end

	return transformer
end

-- Node collector - collects nodes of specific types
export type NodeCollector = Visitor & {
	collected: { ASTNode },
	node_types: { [string]: boolean },
	collect: (self: NodeCollector, node: ASTNode, node_types: { string }) -> { ASTNode },
}

function Visitor.new_collector(): NodeCollector
	local collector = Visitor.new() :: any
	collector.collected = {}
	collector.node_types = {}

	function collector:collect(node: ASTNode, node_types: { string }): { ASTNode }
		self.collected = {}
		self.node_types = {}

		for _, node_type in ipairs(node_types) do
			self.node_types[node_type] = true
		end

		self:visit(node)
		return self.collected
	end

	-- Override generic_visit to collect matching nodes
	function collector:generic_visit(node: ASTNode): any
		if self.node_types[node.type] then
			table.insert(self.collected, node)
		end

		-- Continue with normal traversal
		Visitor.generic_visit(self, node)
		return nil
	end

	return collector
end

return Visitor
