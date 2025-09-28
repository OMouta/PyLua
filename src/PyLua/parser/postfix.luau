local tokens = require("../tokens")
local nodes = require("../ast/nodes")

export type Token = tokens.Token
export type Expr = nodes.Expr

local postfix = {}

-- Forward-declared expression parser injected to avoid cycles
export type ExpressionParser = (state: any) -> Expr

-- Parse function call arguments and keywords
local function parseCallArgs(state: any, parseExpression: ExpressionParser): ({ Expr }, { any })
	local args: { Expr } = {}
	local keywords: { any } = {}
	while state.current and state.current.type ~= "RPAR" do
		if
			state.current.type == "NAME"
			and state.pos < #state.tokens
			and state.tokens[state.pos + 1].type == "EQUAL"
		then
			local nameTok: Token = state.current
			state:advance() -- name
			state:advance() -- '='
			local valueExpr = parseExpression(state)
			table.insert(
				keywords,
				{ arg = nameTok.value, value = valueExpr, lineno = nameTok.line, col_offset = nameTok.column }
			)
		elseif state.current.type == "STAR" then
			state:advance()
			local starredValue = parseExpression(state)
			table.insert(args, {
				type = "Starred",
				value = starredValue,
				ctx = "Load",
				lineno = starredValue.lineno,
				col_offset = starredValue.col_offset,
			})
		elseif state.current.type == "DOUBLESTAR" then
			state:advance()
			local kwValue = parseExpression(state)
			table.insert(
				keywords,
				{ arg = nil, value = kwValue, lineno = kwValue.lineno, col_offset = kwValue.col_offset }
			)
		else
			local expr = parseExpression(state)
			table.insert(args, expr)
		end
		if state.current and state.current.type == "COMMA" then
			state:advance()
			if state.current and state.current.type == "RPAR" then
				break
			end
		else
			break
		end
	end
	return args, keywords
end

function postfix.parse(state: any, expr: Expr, parseExpression: ExpressionParser): Expr
	while true do
		local current: Token? = state.current
		if not current then
			break
		end
		if current.type == "DOT" then
			state:advance()
			local nameTok: Token = state:consume("NAME", "Expected attribute name after '.'")
			expr = {
				type = "Attribute",
				value = expr,
				attr = nameTok.value,
				ctx = "Load",
				lineno = nameTok.line,
				col_offset = nameTok.column,
			}
		elseif current.type == "LSQB" then
			state:advance()
			local indexExpr = parseExpression(state)
			state:consume("RSQB", "Expected ']' after subscript expression")
			expr = {
				type = "Subscript",
				value = expr,
				slice = indexExpr,
				ctx = "Load",
				lineno = indexExpr.lineno,
				col_offset = indexExpr.col_offset,
			}
		elseif current.type == "LPAR" then
			state:advance()
			local args, keywords = parseCallArgs(state, parseExpression)
			state:consume("RPAR", "Expected ')' to close call arguments")
			expr = {
				type = "Call",
				func = expr,
				args = args,
				keywords = keywords,
				lineno = expr.lineno,
				col_offset = expr.col_offset,
			}
		else
			break
		end
	end
	return expr
end

return postfix
