local tokens = require("../../tokens")
local nodes = require("../../ast/nodes")

export type Token = tokens.Token
export type Expr = nodes.Expr
export type Arguments = nodes.Arguments

local MAX_LAMBDA_NESTING = 64

export type LambdaDeps = {
	precedence: any,
	postfix: any,
	parseBinaryExpression: (state: any, minPrec: number) -> Expr,
	parseExpression: (state: any) -> Expr,
	newArguments: () -> Arguments,
}

local function enterLambda(state: any)
	local depth = (state.lambdaDepth or 0) + 1
	if depth > MAX_LAMBDA_NESTING then
		state:raise("Lambda expression nesting too deep")
	end
	state.lambdaDepth = depth
end

local function leaveLambda(state: any)
	local depth = (state.lambdaDepth or 1) - 1
	if depth <= 0 then
		state.lambdaDepth = nil
	else
		state.lambdaDepth = depth
	end
end

local function createLambdaModule(deps: LambdaDeps)
	local precedence = deps.precedence
	local parseBinaryExpression = deps.parseBinaryExpression
	local parseExpression = deps.parseExpression
	local postfix = deps.postfix
	local newArguments = deps.newArguments

	local function parseLambdaParameters(state: any): Arguments
		local args = newArguments()

		while state.current and state.current.type ~= "COLON" do
			if state.current.type ~= "NAME" then
				state:raise("Expected parameter name in lambda")
			end
			local paramToken: Token = state.current
			state:advance()
			local param: nodes.Arg = {
				arg = paramToken.value,
				annotation = nil,
				lineno = paramToken.line,
				col_offset = paramToken.column,
				end_lineno = paramToken.endLine,
				end_col_offset = paramToken.endColumn,
			}
			table.insert(args.args, param)

			if state.current and state.current.type == "EQUAL" then
				state:advance()
				local defaultExpr = parseBinaryExpression(state, precedence.LAMBDA)
				table.insert(args.defaults, defaultExpr)
			end

			if not state.current or state.current.type ~= "COMMA" then
				break
			end

			local lookaheadToken = state:lookahead(1)
			state:advance()
			if not lookaheadToken or lookaheadToken.type == "COLON" then
				break
			end
		end

		return args
	end

	local function parseLambda(state: any): Expr
		local lambdaToken: Token = state.current :: Token
		enterLambda(state)
		state:advance()

		local args = newArguments()
		if state.current and state.current.type ~= "COLON" then
			args = parseLambdaParameters(state)
		end

		state:consume("COLON", "Expected ':' after lambda parameters")
		local bodyExpr = parseBinaryExpression(state, precedence.LAMBDA)

		local lambdaNode: Expr = {
			type = "Lambda",
			args = args,
			body = bodyExpr,
			lineno = lambdaToken.line,
			col_offset = lambdaToken.column,
			end_lineno = bodyExpr.end_lineno,
			end_col_offset = bodyExpr.end_col_offset,
		}

		local result = postfix.parse(state, lambdaNode, parseExpression)
		leaveLambda(state)
		return result
	end

	return {
		parseLambda = parseLambda,
	}
end

return {
	new = createLambdaModule,
}
