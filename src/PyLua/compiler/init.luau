local State = require("@self/state")
local expressionsFactory = require("@self/expressions")
local statementsFactory = require("@self/statements")

export type CodeObject = State.CodeObject

local Compiler = {}

local compileStmtImpl: ((State.CompilerState, any) -> ())? = nil

local function compileStmt(st: State.CompilerState, node: any)
	if not compileStmtImpl then
		error("Compiler pipeline not initialized", 2)
	end
	compileStmtImpl(st, node)
end

local expressions = expressionsFactory({
	compileStmt = compileStmt,
})

local statements = statementsFactory({
	compileExpr = expressions.compileExpr,
	compileAssignmentTarget = expressions.compileAssignmentTarget,
	compileLoadTarget = expressions.compileLoadTarget,
	compileStoreTarget = expressions.compileStoreTarget,
	resolveBinOpOpcode = expressions.resolveBinOpOpcode,
})

compileStmtImpl = statements.compileStmt

local function compileModule(ast: any): CodeObject
	local st = State.newState()
	st.code.firstlineno = ast.lineno
	for _, stmt in ipairs(ast.body) do
		compileStmt(st, stmt)
	end
	local idxNone = State.addConst(st, nil)
	State.emit(st, "LOAD_CONST", idxNone, ast.lineno)
	State.emit(st, "RETURN_VALUE", nil, ast.lineno)
	return st.code
end

function Compiler.compile(ast: any): CodeObject
	if ast.type == "Module" then
		return compileModule(ast)
	end

	local exprNode = ast
	if ast.type == "Expr" and ast.value then
		exprNode = ast.value
	end

	if exprNode and exprNode.type then
		local lineno = exprNode.lineno or 1
		local col = exprNode.col_offset or 0
		local fakeModule = {
			type = "Module",
			body = {
				{
					type = "Return",
					value = exprNode,
					lineno = lineno,
					col_offset = col,
				},
			},
			lineno = lineno,
			col_offset = col,
		}
		return compileModule(fakeModule)
	end

	error("Unsupported root AST for compile: " .. tostring(ast.type))
end

return Compiler
