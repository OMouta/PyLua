local tokens = require("../../tokens")
local nodes = require("../../ast/nodes")
local precedenceModule = require("../precedence")

export type Token = tokens.Token
export type Expr = nodes.Expr
export type CmpOp = nodes.CmpOp

export type BinaryDeps = {
	precedence: typeof(precedenceModule),
	parsePrimary: (state: any) -> Expr,
	parseLambda: (state: any) -> Expr,
}

local function lookahead(state: any, offset: number): Token?
	local idx = state.pos + offset
	if idx >= 1 and idx <= #state.tokens then
		return state.tokens[idx]
	end
	return nil
end

local function getCompareOp(tokenType: string, nextTok: Token?): CmpOp?
	if tokenType == "EQEQUAL" then
		return "Eq" :: CmpOp
	end
	if tokenType == "NOTEQUAL" then
		return "NotEq" :: CmpOp
	end
	if tokenType == "LESS" then
		return "Lt" :: CmpOp
	end
	if tokenType == "LESSEQUAL" then
		return "LtE" :: CmpOp
	end
	if tokenType == "GREATER" then
		return "Gt" :: CmpOp
	end
	if tokenType == "GREATEREQUAL" then
		return "GtE" :: CmpOp
	end
	if tokenType == "IS" then
		if nextTok and nextTok.type == "NOT" then
			return "IsNot" :: CmpOp
		end
		return "Is" :: CmpOp
	end
	if tokenType == "IN" then
		return "In" :: CmpOp
	end
	if tokenType == "NOT" and nextTok and nextTok.type == "IN" then
		return "NotIn" :: CmpOp
	end
	return nil
end

local function createBinaryModule(deps: BinaryDeps)
	local precedence = deps.precedence
	local PRECEDENCE = precedence.LEVELS
	local BINOP_MAP = precedence.BINOP_MAP
	local parsePrimary = deps.parsePrimary
	local parseLambda = deps.parseLambda
	local parseBinaryExpression: (state: any, minPrec: number) -> Expr

	local function isYieldTerminator(tokenType: string): boolean
		return tokenType == "COMMA"
			or tokenType == "COLON"
			or tokenType == "RPAR"
			or tokenType == "RSQB"
			or tokenType == "RBRACE"
			or tokenType == "NEWLINE"
			or tokenType == "ENDMARKER"
			or tokenType == "DEDENT"
			or tokenType == "SEMICOLON"
	end

	local function parseYieldExpression(state: any): Expr
		local yieldToken: Token = state.current :: Token
		state:advance()
		if state.current and state.current.type == "FROM" then
			state:advance()
			local valueExpr = parseBinaryExpression(state, precedence.LAMBDA)
			return {
				type = "YieldFrom",
				value = valueExpr,
				lineno = yieldToken.line,
				col_offset = yieldToken.column,
			}
		end
		local valueExpr: Expr? = nil
		if state.current and not isYieldTerminator(state.current.type) then
			valueExpr = parseBinaryExpression(state, precedence.LAMBDA)
		end
		return {
			type = "Yield",
			value = valueExpr,
			lineno = yieldToken.line,
			col_offset = yieldToken.column,
		}
	end

	local function parseUnary(state: any): Expr
		local current: Token? = state.current
		if not current then
			return parsePrimary(state)
		end
		if current.type == "YIELD" then
			return parseYieldExpression(state)
		end
		if current.type == "MINUS" then
			state:advance()
			local operand = parseUnary(state)
			return {
				type = "UnaryOp",
				op = "USub",
				operand = operand,
				lineno = current.line,
				col_offset = current.column,
			}
		end
		if current.type == "PLUS" then
			state:advance()
			local operand = parseUnary(state)
			return {
				type = "UnaryOp",
				op = "UAdd",
				operand = operand,
				lineno = current.line,
				col_offset = current.column,
			}
		end
		if current.type == "TILDE" then
			state:advance()
			local operand = parseUnary(state)
			return {
				type = "UnaryOp",
				op = "Invert",
				operand = operand,
				lineno = current.line,
				col_offset = current.column,
			}
		end
		if current.type == "NOT" then
			state:advance()
			local operand = parseUnary(state)
			return {
				type = "UnaryOp",
				op = "Not",
				operand = operand,
				lineno = current.line,
				col_offset = current.column,
			}
		end
		return parsePrimary(state)
	end

	local function parsePrefix(state: any, _minPrec: number): Expr
		local current: Token? = state.current
		if current and current.type == "LAMBDA" then
			return parseLambda(state)
		end
		return parseUnary(state)
	end

	parseBinaryExpression = function(state: any, minPrec: number): Expr
		local left = parsePrefix(state, minPrec)

		local function foldComparison(base: Expr, firstTok: Token, firstOp: CmpOp): Expr
			local ops = { firstOp }
			local comparators: { Expr } = {}
			local rhs = parseBinaryExpression(state, PRECEDENCE[firstTok.type] + 1)
			table.insert(comparators, rhs)
			while true do
				local t: Token? = state.current
				if not t then
					break
				end
				local nextTok = lookahead(state, 1)
				local op2 = t and getCompareOp(t.type, nextTok)
				if not op2 then
					break
				end
				if t.type == "IS" and nextTok and nextTok.type == "NOT" then
					state:advance()
					state:advance()
				elseif t.type == "NOT" and nextTok and nextTok.type == "IN" then
					state:advance()
					state:advance()
				else
					state:advance()
				end
				local r2 = parseBinaryExpression(state, PRECEDENCE[t.type] + 1)
				table.insert(ops, op2)
				table.insert(comparators, r2)
			end
			return {
				type = "Compare",
				left = base,
				ops = ops,
				comparators = comparators,
				lineno = firstTok.line,
				col_offset = firstTok.column,
			}
		end

		while true do
			local currentTok: Token? = state.current
			if not currentTok then
				break
			end
			local prec = PRECEDENCE[currentTok.type]
			if not prec or prec < minPrec then
				break
			end
			if currentTok.type == "AND" or currentTok.type == "OR" then
				local boolType = (currentTok.type == "AND") and "And" or "Or"
				local operatorTokenType = currentTok.type
				local values = { left }
				repeat
					state:advance()
					local rhs = parseBinaryExpression(state, PRECEDENCE[operatorTokenType] + 1)
					table.insert(values, rhs)
					currentTok = state.current
				until not currentTok or currentTok.type ~= operatorTokenType
				left = {
					type = "BoolOp",
					op = boolType,
					values = values,
					lineno = values[1].lineno,
					col_offset = values[1].col_offset,
				}
			else
				local nextTok = lookahead(state, 1)
				local cmpOp: CmpOp? = getCompareOp(currentTok.type, nextTok)
				if cmpOp then
					local cmp = (cmpOp) :: CmpOp
					local opToken: Token = currentTok
					if currentTok.type == "IS" and nextTok and nextTok.type == "NOT" then
						state:advance()
						state:advance()
					elseif currentTok.type == "NOT" and nextTok and nextTok.type == "IN" then
						state:advance()
						state:advance()
					else
						state:advance()
					end
					left = foldComparison(left, opToken, cmp :: CmpOp)
				else
					local op = BINOP_MAP[currentTok.type]
					if not op then
						break
					end
					state:advance()
					local right = parseBinaryExpression(state, prec + 1)
					left = {
						type = "BinOp",
						left = left,
						op = op,
						right = right,
						lineno = currentTok.line,
						col_offset = currentTok.column,
					}
				end
			end
		end

		return left
	end

	return {
		parseBinaryExpression = parseBinaryExpression,
		parseUnary = parseUnary,
	}
end

return {
	new = createBinaryModule,
}
