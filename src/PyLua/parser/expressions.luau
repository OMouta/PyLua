--!strict
-- Expression parsing module (literals, unary, binary, comparisons, collections)

local tokens = require("../tokens")
local nodes = require("../ast/nodes")
local precedence = require("./precedence")
local postfix = require("./postfix")

export type Token = tokens.Token
export type TokenType = tokens.TokenType
export type Expr = nodes.Expr

local expressions = {}

-- Binary op helpers
local BINOP_MAP = precedence.BINOP_MAP
local PRECEDENCE = precedence.LEVELS

-- Utility lookahead
local function lookahead(state: any, offset: number): Token?
	local idx = state.pos + offset
	if idx >= 1 and idx <= #state.tokens then
		return state.tokens[idx]
	end
	return nil
end

-- Comparison operator mapping
local function getCompareOp(tokenType: string, nextTok: Token?): nodes.CmpOp?
	if tokenType == "EQEQUAL" then
		return "Eq"
	end
	if tokenType == "NOTEQUAL" then
		return "NotEq"
	end
	if tokenType == "LESS" then
		return "Lt"
	end
	if tokenType == "LESSEQUAL" then
		return "LtE"
	end
	if tokenType == "GREATER" then
		return "Gt"
	end
	if tokenType == "GREATEREQUAL" then
		return "GtE"
	end
	if tokenType == "IS" then
		if nextTok and nextTok.type == "NOT" then
			return "IsNot"
		end
		return "Is"
	end
	if tokenType == "IN" then
		return "In"
	end
	if tokenType == "NOT" and nextTok and nextTok.type == "IN" then
		return "NotIn"
	end
	return nil
end

local function parsePrimary(state: any): Expr
	local currentOpt: Token? = state.current
	if not currentOpt then
		state:raise("Unexpected end of input in expression")
	end
	local current: Token = currentOpt :: Token
	-- Explicitly disallow matrix multiply '@' until opcode is implemented
	if current.type == "AT" then
		state:raise("Matrix multiply '@' is not supported yet")
	end
	-- Numbers
	if current.type == "NUMBER" then
		state:advance()
		local value = current.value
		local numValue: any
		if string.find(value, "^0b") then
			numValue = tonumber(string.sub(value, 3), 2)
		elseif string.find(value, "^0o") then
			numValue = tonumber(string.sub(value, 3), 8)
		elseif string.find(value, "^0x") then
			numValue = tonumber(string.sub(value, 3), 16)
		elseif string.find(value, "%.") or string.find(value, "[eE]") then
			numValue = tonumber(value)
		else
			numValue = tonumber(value)
		end
		return { type = "Constant", value = numValue, kind = nil, lineno = current.line, col_offset = current.column }
	end
	-- Strings (with prefix/triple support)
	if current.type == "STRING" then
		state:advance()
		local kind = (current :: any).stringPrefix
		local content = (current :: any).stringContent
		local val: string
		if content ~= nil then
			val = content
		else
			-- Fallback: derive content from value by stripping quotes (handles single or triple)
			local v = current.value
			if #v >= 6 and ((string.sub(v, 1, 3) == "\"\"\"" and string.sub(v, -3) == "\"\"\"")
				or (string.sub(v, 1, 3) == "'''" and string.sub(v, -3) == "'''") ) then
				val = string.sub(v, 4, -4)
			elseif #v >= 2 and ((string.sub(v, 1, 1) == '"' and string.sub(v, -1) == '"')
				or (string.sub(v, 1, 1) == "'" and string.sub(v, -1) == "'")) then
				val = string.sub(v, 2, -2)
			else
				val = v
			end
		end
		-- Normalize string prefixes:
		-- - Treat 'u' like no-op (Python 3.x)
		-- - If contains 'b' (and not 'f'), mark as bytes literal via kind = "bytes"
		-- - Keep 'f' for future f-string handling (value stays raw here)
		local outKind: string? = kind
		if outKind and string.find(outKind, "u", 1, true) then
			outKind = string.gsub(outKind, "u", "")
			if outKind == "" then outKind = nil end
		end
		local isBytes = outKind and string.find(outKind, "b", 1, true) ~= nil
		if isBytes then
			outKind = "bytes"
		end
		return { type = "Constant", value = val, kind = outKind, lineno = current.line, col_offset = current.column }
	end
	if current.type == "TRUE" then
		state:advance()
		return { type = "Constant", value = true, kind = nil, lineno = current.line, col_offset = current.column }
	end
	if current.type == "FALSE" then
		state:advance()
		return { type = "Constant", value = false, kind = nil, lineno = current.line, col_offset = current.column }
	end
	if current.type == "NONE" then
		state:advance()
		return { type = "Constant", value = nil, kind = nil, lineno = current.line, col_offset = current.column }
	end
	if current.type == "NAME" then
		state:advance()
		local node: Expr =
			{ type = "Name", id = current.value, ctx = "Load", lineno = current.line, col_offset = current.column }
		return postfix.parse(state, node, expressions.parse)
	end
	-- List
	if current.type == "LSQB" then
		state:advance()
		local elts: { Expr } = {}
		while state.current and state.current.type ~= "RSQB" do
			if state.current.type == "STAR" then
				state:advance()
				local starredValue = expressions.parse(state)
				table.insert(elts, {
					type = "Starred",
					value = starredValue,
					ctx = "Load",
					lineno = starredValue.lineno,
					col_offset = starredValue.col_offset,
				})
			else
				local elt = expressions.parse(state)
				table.insert(elts, elt)
			end
			if state.current and state.current.type == "COMMA" then
				state:advance()
			else
				break
			end
		end
		state:consume("RSQB", "Expected ']' to close list literal")
		local listNode: Expr =
			{ type = "List", elts = elts, ctx = "Load", lineno = current.line, col_offset = current.column }
		return postfix.parse(state, listNode, expressions.parse)
	end
	-- Dict / Set / {} / {**}
	if current.type == "LBRACE" then
		state:advance()
		local keys: { Expr? } = {}
		local values: { Expr } = {}
		local elts: { Expr } = {}
		local isDict = false
		local hasElements = false
		while state.current and state.current.type ~= "RBRACE" do
			hasElements = true
			if state.current.type == "DOUBLESTAR" then
				state:advance()
				local unpackExpr = expressions.parse(state)
				local unpackNode: Expr = {
					type = "DictUnpack",
					value = unpackExpr,
					lineno = unpackExpr.lineno,
					col_offset = unpackExpr.col_offset,
				}
				table.insert(keys, unpackNode)
				table.insert(values, unpackExpr)
				isDict = true
			else
				local firstExpr: Expr
				if state.current.type == "STAR" then
					state:advance()
					local starredInner = expressions.parse(state)
					firstExpr = {
						type = "Starred",
						value = starredInner,
						ctx = "Load",
						lineno = starredInner.lineno,
						col_offset = starredInner.col_offset,
					}
				else
					firstExpr = expressions.parse(state)
				end
				if state.current and state.current.type == "COLON" then
					isDict = true
					state:advance()
					local valueExpr = expressions.parse(state)
					table.insert(keys, firstExpr)
					table.insert(values, valueExpr)
				else
					if isDict then
						state:raise("Mixed set and dict elements in literal")
					end
					table.insert(elts, firstExpr)
				end
			end
			if state.current and state.current.type == "COMMA" then
				state:advance()
			else
				break
			end
		end
		state:consume("RBRACE", "Expected '}' to close literal")
		local node: Expr
		if not hasElements then
			node = { type = "Dict", keys = {}, values = {}, lineno = current.line, col_offset = current.column }
		elseif isDict then
			node = { type = "Dict", keys = keys, values = values, lineno = current.line, col_offset = current.column }
		else
			node = { type = "Set", elts = elts, lineno = current.line, col_offset = current.column }
		end
		return postfix.parse(state, node, expressions.parse)
	end
	-- Parenthesized / tuple
	if current.type == "LPAR" then
		state:advance()
		if state.current and state.current.type == "RPAR" then
			state:advance()
			local tupleNode: Expr =
				{ type = "Tuple", elts = {}, ctx = "Load", lineno = current.line, col_offset = current.column }
			return postfix.parse(state, tupleNode, expressions.parse)
		end
		local elements: { Expr } = {}
		local first: Expr
		if state.current and state.current.type == "STAR" then
			state:advance()
			local starredInner = expressions.parse(state)
			first = {
				type = "Starred",
				value = starredInner,
				ctx = "Load",
				lineno = starredInner.lineno,
				col_offset = starredInner.col_offset,
			}
		else
			first = expressions.parse(state)
		end
		if state.current and state.current.type == "COMMA" then
			table.insert(elements, first)
			while state.current and state.current.type == "COMMA" do
				state:advance()
				if state.current and state.current.type == "RPAR" then
					break
				end
				local nextExpr: Expr
				if state.current and state.current.type == "STAR" then
					state:advance()
					local starredInner = expressions.parse(state)
					nextExpr = {
						type = "Starred",
						value = starredInner,
						ctx = "Load",
						lineno = starredInner.lineno,
						col_offset = starredInner.col_offset,
					}
				else
					nextExpr = expressions.parse(state)
				end
				table.insert(elements, nextExpr)
			end
			state:consume("RPAR", "Expected ')' to close tuple")
			local tupleNode: Expr =
				{ type = "Tuple", elts = elements, ctx = "Load", lineno = first.lineno, col_offset = first.col_offset }
			return postfix.parse(state, tupleNode, expressions.parse)
		else
			state:consume("RPAR", "Expected ')' after expression")
			return postfix.parse(state, first, expressions.parse)
		end
	end

	-- If we get here, we have an unexpected token; raise immediately
	state:raise("Unexpected token in expression: " .. current.type)
	-- Unreachable; return added for typechecker friendliness
	return { type = "Constant", value = nil, kind = nil, lineno = current.line, col_offset = current.column }
end

local function parseUnary(state: any): Expr
	local current: Token? = state.current
	if not current then
		return parsePrimary(state)
	end
	if current.type == "MINUS" then
		state:advance()
		local operand = parseUnary(state)
		return { type = "UnaryOp", op = "USub", operand = operand, lineno = current.line, col_offset = current.column }
	end
	if current.type == "PLUS" then
		state:advance()
		local operand = parseUnary(state)
		return { type = "UnaryOp", op = "UAdd", operand = operand, lineno = current.line, col_offset = current.column }
	end
	if current.type == "TILDE" then
		state:advance()
		local operand = parseUnary(state)
		return { type = "UnaryOp", op = "Invert", operand = operand, lineno = current.line, col_offset = current.column }
	end
	if current.type == "NOT" then
		state:advance()
		local operand = parseUnary(state)
		return { type = "UnaryOp", op = "Not", operand = operand, lineno = current.line, col_offset = current.column }
	end
	return parsePrimary(state)
end

local function parseBinaryExpression(state: any, minPrec: number): Expr
	local left = parseUnary(state)
	local function foldComparison(base: Expr, firstTok: Token, firstOp: nodes.CmpOp): Expr
		local ops = { firstOp }
		local comparators: { Expr } = {}
		local rhs = parseUnary(state)
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
			local r2 = parseUnary(state)
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
		local current: Token? = state.current
		if not current then
			break
		end
		local prec = PRECEDENCE[current.type]
		if not prec or prec < minPrec then
			break
		end
		if current.type == "AND" or current.type == "OR" then
			local boolType = (current.type == "AND") and "And" or "Or"
			local values = { left }
			repeat
				state:advance()
				local rhs = parseBinaryExpression(state, PRECEDENCE[current.type] + 1)
				table.insert(values, rhs)
				current = state.current
			until not current or current.type ~= ((boolType == "And") and "AND" or "OR")
			left = {
				type = "BoolOp",
				op = boolType,
				values = values,
				lineno = values[1].lineno,
				col_offset = values[1].col_offset,
			}
		else
			local nextTok = lookahead(state, 1)
			local cmpOp = getCompareOp(current.type, nextTok)
			if cmpOp then
				local opToken: Token = current
				if current.type == "IS" and nextTok and nextTok.type == "NOT" then
					state:advance()
					state:advance()
				elseif current.type == "NOT" and nextTok and nextTok.type == "IN" then
					state:advance()
					state:advance()
				else
					state:advance()
				end
				left = foldComparison(left, opToken, cmpOp :: nodes.CmpOp)
			else
				local op = BINOP_MAP[current.type]
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
					lineno = current.line,
					col_offset = current.column,
				}
			end
		end
	end
	return left
end

function expressions.parse(state: any): Expr
	return parseBinaryExpression(state, 1)
end

-- Expose helpers used by statements module for assignment target parsing
function expressions.parsePrimaryForTarget(state: any): Expr?
	-- Accept simple NAME start then allow postfix chain
	local tok: Token? = state.current
	if not tok or tok.type ~= "NAME" then
		return nil
	end
	local savedPos = state.pos
	local savedTok = tok
	local node = parsePrimary(state)
	-- parsePrimary already applied postfix; ensure it's a valid target base
	return node
end

return expressions
