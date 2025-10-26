local tokens = require("../tokens")
local nodes = require("../ast/nodes")
local precedence = require("./precedence")
local postfix = require("./postfix")
local lexer = require("../lexer")

export type Token = tokens.Token
export type TokenType = tokens.TokenType
export type Expr = nodes.Expr

local expressions = {}

local function prefixContains(prefix: string?, flag: string): boolean
	if not prefix then
		return false
	end
	return string.find(prefix, flag, 1, true) ~= nil
end

local function makeStringConstant(token: Token): Expr
	local prefix = (token :: any).stringPrefix
	local content = (token :: any).stringContent
	local value: string
	if content ~= nil then
		value = content
	else
		local v = token.value
		if
			#v >= 6
			and (
				(string.sub(v, 1, 3) == '"""' and string.sub(v, -3) == '"""')
				or (string.sub(v, 1, 3) == "'''" and string.sub(v, -3) == "'''")
			)
		then
			value = string.sub(v, 4, -4)
		elseif
			#v >= 2
			and (
				(string.sub(v, 1, 1) == '"' and string.sub(v, -1) == '"')
				or (string.sub(v, 1, 1) == "'" and string.sub(v, -1) == "'")
			)
		then
			value = string.sub(v, 2, -2)
		else
			value = v
		end
	end

	local outKind = prefix
	if outKind and string.find(outKind, "u", 1, true) then
		outKind = string.gsub(outKind, "u", "")
		if outKind == "" then
			outKind = nil
		end
	end
	local isBytes = outKind and string.find(outKind, "b", 1, true) ~= nil
	if isBytes then
		outKind = "bytes"
	end

	return {
		type = "Constant",
		value = value,
		kind = outKind,
		lineno = token.line,
		col_offset = token.column,
	}
end

local function makeNameNode(id: string, baseNode: Expr?, token: Token): Expr
	local lineno = if baseNode then baseNode.lineno else token.line
	local col = if baseNode then baseNode.col_offset else token.column
	return { type = "Name", id = id, ctx = "Load", lineno = lineno, col_offset = col }
end

local function wrapCall(funcName: string, argList: { Expr }, baseNode: Expr, token: Token): Expr
	local funcNode = makeNameNode(funcName, baseNode, token)
	return {
		type = "Call",
		func = funcNode,
		args = argList,
		keywords = {},
		lineno = baseNode.lineno,
		col_offset = baseNode.col_offset,
	}
end

local function foldConcat(parts: { Expr }, token: Token): Expr
	if #parts == 0 then
		return {
			type = "Constant",
			value = "",
			kind = nil,
			lineno = token.line,
			col_offset = token.column,
		}
	end
	local result: Expr = parts[1]
	for i = 2, #parts do
		result = {
			type = "BinOp",
			left = result,
			op = "Add",
			right = parts[i],
			lineno = token.line,
			col_offset = token.column,
		}
	end
	return result
end

local function newArguments(): nodes.Arguments
	return {
		posonlyargs = {},
		args = {},
		vararg = nil,
		kwonlyargs = {},
		kw_defaults = {},
		kwarg = nil,
		defaults = {},
	}
end

local function parseLambdaParameters(state: any): nodes.Arguments
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
			local defaultExpr = expressions.parse(state)
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
	state:advance()

	local args = newArguments()
	if state.current and state.current.type ~= "COLON" then
		args = parseLambdaParameters(state)
	end

	state:consume("COLON", "Expected ':' after lambda parameters")
	local bodyExpr = expressions.parse(state)

	local lambdaNode: Expr = {
		type = "Lambda",
		args = args,
		body = bodyExpr,
		lineno = lambdaToken.line,
		col_offset = lambdaToken.column,
		end_lineno = bodyExpr.end_lineno,
		end_col_offset = bodyExpr.end_col_offset,
	}

	return postfix.parse(state, lambdaNode, expressions.parse)
end

local function makeSubState(tokenList: { Token }, parentState: any)
	local sub: any = {
		tokens = tokenList,
		pos = 1,
		current = tokenList[1],
	}

	function sub:advance()
		if self.pos < #self.tokens then
			self.pos += 1
			self.current = self.tokens[self.pos]
		else
			self.current = nil
		end
	end

	function sub:lookahead(offset: number): Token?
		local idx = self.pos + offset
		if idx >= 1 and idx <= #self.tokens then
			return self.tokens[idx]
		end
		return nil
	end

	function sub:consume(tokenType: string, message: string?): Token
		local cur = self.current
		if not cur then
			parentState:raise(message or ("Expected " .. tokenType .. " in f-string expression"))
		end
		if cur.type ~= tokenType then
			parentState:raise(message or ("Expected " .. tokenType .. " in f-string expression, got " .. cur.type))
		end
		self:advance()
		return cur :: any
	end

	function sub:raise(msg: string)
		parentState:raise(msg)
	end

	return sub
end

local function parseEmbeddedExpression(exprText: string, state: any, token: Token): Expr
	local exprTokens = lexer.tokenize(exprText)
	local subState = makeSubState(exprTokens, state)
	local exprNode = expressions.parse(subState)
	while subState.current and (subState.current.type == "NEWLINE" or subState.current.type == "ENDMARKER") do
		subState:advance()
	end
	if subState.current then
		state:raise("Unexpected token after expression in f-string")
	end
	return exprNode
end

local function buildFormattedValue(
	exprNode: Expr,
	conversion: string?,
	formatSpec: string?,
	token: Token,
	state: any
): Expr
	local converted = exprNode
	if conversion == "s" then
		converted = wrapCall("str", { converted }, exprNode, token)
	elseif conversion == "r" then
		converted = wrapCall("repr", { converted }, exprNode, token)
	elseif conversion == "a" then
		converted = wrapCall("ascii", { converted }, exprNode, token)
	elseif conversion ~= nil then
		state:raise("Unsupported conversion specifier in f-string: !" .. tostring(conversion))
	end

	if formatSpec and formatSpec ~= "" then
		local specConst: Expr = {
			type = "Constant",
			value = formatSpec,
			kind = nil,
			lineno = token.line,
			col_offset = token.column,
		}
		converted = wrapCall("format", { converted, specConst }, converted, token)
	elseif conversion == nil then
		converted = wrapCall("str", { converted }, exprNode, token)
	end

	return converted
end

local function parseFormattedSection(content: string, startIndex: number, state: any, token: Token): (Expr, number)
	local len = #content
	local i = startIndex + 1
	local exprStart = i
	local braceDepth = 0
	local parenDepth = 0
	local bracketDepth = 0
	local inStringQuote: string? = nil
	local stringTriple = false
	local conversion: string? = nil
	local formatStart: number? = nil
	local exprEndIndex: number? = nil

	while i <= len do
		if inStringQuote then
			if stringTriple then
				if i + 2 <= len and content:sub(i, i + 2) == string.rep(inStringQuote, 3) then
					inStringQuote = nil
					stringTriple = false
					i += 3
				else
					i += 1
				end
			else
				local ch = content:sub(i, i)
				if ch == "\\" then
					i += 2
				elseif ch == inStringQuote then
					inStringQuote = nil
					i += 1
				else
					i += 1
				end
			end
		else
			local ch = content:sub(i, i)
			if ch == "'" or ch == '"' then
				local triple = i + 2 <= len and content:sub(i, i + 2) == ch .. ch .. ch
				inStringQuote = ch
				stringTriple = triple
				i += if triple then 3 else 1
			elseif ch == "(" then
				parenDepth += 1
				i += 1
			elseif ch == ")" then
				if parenDepth > 0 then
					parenDepth -= 1
				end
				i += 1
			elseif ch == "[" then
				bracketDepth += 1
				i += 1
			elseif ch == "]" then
				if bracketDepth > 0 then
					bracketDepth -= 1
				end
				i += 1
			elseif ch == "{" then
				braceDepth += 1
				i += 1
			elseif ch == "}" then
				if braceDepth == 0 then
					if not exprEndIndex then
						exprEndIndex = i - 1
					end
					break
				else
					braceDepth -= 1
					i += 1
				end
			elseif
				ch == "!"
				and braceDepth == 0
				and parenDepth == 0
				and bracketDepth == 0
				and conversion == nil
				and formatStart == nil
			then
				local convChar = content:sub(i + 1, i + 1)
				if convChar == "" then
					state:raise("Conversion specifier in f-string is missing")
				end
				if convChar ~= "s" and convChar ~= "r" and convChar ~= "a" then
					state:raise("Unsupported conversion specifier in f-string: !" .. convChar)
				end
				conversion = convChar
				exprEndIndex = exprEndIndex or (i - 1)
				i += 2
			elseif ch == ":" and braceDepth == 0 and parenDepth == 0 and bracketDepth == 0 and formatStart == nil then
				exprEndIndex = exprEndIndex or (i - 1)
				formatStart = i + 1
				i += 1
			elseif
				ch == "="
				and braceDepth == 0
				and parenDepth == 0
				and bracketDepth == 0
				and conversion == nil
				and formatStart == nil
			then
				state:raise("Debug f-string expressions (expr=) are not supported yet")
			else
				i += 1
			end
		end
	end

	if i > len then
		state:raise("F-string expression is missing closing '}'")
	end

	local exprStop = exprEndIndex or (i - 1)
	if exprStop < exprStart then
		state:raise("Empty expression in f-string")
	end

	local exprSlice = string.sub(content, exprStart, exprStop)
	local exprText = (string.match(exprSlice, "^%s*(.-)%s*$") or "")
	if exprText == "" then
		state:raise("Empty expression in f-string")
	end

	local exprNode = parseEmbeddedExpression(exprText, state, token)

	local formatSpecText: string? = nil
	if formatStart then
		local rawSpec = string.sub(content, formatStart, i - 1)
		local trimmed = string.match(rawSpec, "^%s*(.-)%s*$") or ""
		if trimmed ~= "" then
			local check = trimmed:gsub("{{", ""):gsub("}}", "")
			if string.find(check, "{", 1, true) or string.find(check, "}", 1, true) then
				state:raise("Nested expressions in format specifiers are not supported yet")
			end
			formatSpecText = trimmed:gsub("{{", "{"):gsub("}}", "}")
		end
	end

	local formatted = buildFormattedValue(exprNode, conversion, formatSpecText, token, state)
	return formatted, i + 1
end

local function parseFStringLiteral(token: Token, state: any): Expr
	local content = (token :: any).stringContent or ""
	local values: { Expr } = {}
	local literalBuffer: { string } = {}

	local function flushLiteral()
		if #literalBuffer > 0 then
			table.insert(values, {
				type = "Constant",
				value = table.concat(literalBuffer),
				kind = nil,
				lineno = token.line,
				col_offset = token.column,
			})
			literalBuffer = {}
		end
	end

	local i = 1
	local len = #content
	while i <= len do
		local ch = string.sub(content, i, i)
		if ch == "{" then
			if i < len and string.sub(content, i + 1, i + 1) == "{" then
				table.insert(literalBuffer, "{")
				i += 2
			else
				flushLiteral()
				local expr, nextIndex = parseFormattedSection(content, i, state, token)
				table.insert(values, expr)
				i = nextIndex
			end
		elseif ch == "}" then
			if i < len and string.sub(content, i + 1, i + 1) == "}" then
				table.insert(literalBuffer, "}")
				i += 2
			else
				state:raise("Single '}' is not allowed in f-string")
			end
		else
			table.insert(literalBuffer, ch)
			i += 1
		end
	end

	flushLiteral()

	return foldConcat(values, token)
end

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
	if current.type == "LAMBDA" then
		return parseLambda(state)
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
		local node: Expr = {
			type = "Constant",
			value = numValue,
			kind = nil,
			lineno = current.line,
			col_offset = current.column,
		}
		return postfix.parse(state, node, expressions.parse)
	end
	-- Strings (literal concatenation + f-strings)
	if current.type == "STRING" then
		local parts: { Expr } = {}
		while state.current and state.current.type == "STRING" do
			local tok: Token = state.current :: Token
			state:advance()
			local prefix = (tok :: any).stringPrefix
			if prefixContains(prefix, "f") then
				if prefixContains(prefix, "b") then
					state:raise("Cannot combine 'f' and 'b' prefixes in string literal")
				end
				table.insert(parts, parseFStringLiteral(tok, state))
			else
				table.insert(parts, makeStringConstant(tok))
			end
		end
		local node = foldConcat(parts, current)
		return postfix.parse(state, node, expressions.parse)
	end
	if current.type == "TRUE" then
		state:advance()
		local node: Expr = {
			type = "Constant",
			value = true,
			kind = nil,
			lineno = current.line,
			col_offset = current.column,
		}
		return postfix.parse(state, node, expressions.parse)
	end
	if current.type == "FALSE" then
		state:advance()
		local node: Expr = {
			type = "Constant",
			value = false,
			kind = nil,
			lineno = current.line,
			col_offset = current.column,
		}
		return postfix.parse(state, node, expressions.parse)
	end
	if current.type == "NONE" then
		state:advance()
		local node: Expr = {
			type = "Constant",
			value = nil,
			kind = nil,
			lineno = current.line,
			col_offset = current.column,
		}
		return postfix.parse(state, node, expressions.parse)
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
		if state.current and state.current.type == "RSQB" then
			state:advance()
			local emptyList: Expr =
				{ type = "List", elts = {}, ctx = "Load", lineno = current.line, col_offset = current.column }
			return postfix.parse(state, emptyList, expressions.parse)
		end

		local function parseListElement(): Expr
			if not state.current then
				state:raise("Expected expression in list literal")
			end
			if state.current.type == "STAR" then
				state:advance()
				local starredValue = expressions.parse(state)
				return {
					type = "Starred",
					value = starredValue,
					ctx = "Load",
					lineno = starredValue.lineno,
					col_offset = starredValue.col_offset,
				}
			end
			return expressions.parse(state)
		end

		local function setComprehensionTargetContext(expr: Expr)
			local t = expr.type
			if t == "Name" or t == "Attribute" or t == "Subscript" then
				(expr :: any).ctx = "Store"
			elseif t == "Tuple" or t == "List" then
				(expr :: any).ctx = "Store"
				for _, elt in ipairs((expr :: any).elts) do
					setComprehensionTargetContext(elt)
				end
			elseif t == "Starred" then
				(expr :: any).ctx = "Store"
				setComprehensionTargetContext((expr :: any).value)
			else
				state:raise("Invalid comprehension target")
			end
		end

		local function parseComprehensionGenerators(): { nodes.Comprehension }
			local gens: { nodes.Comprehension } = {}
			while state.current and state.current.type == "FOR" do
				state:advance()
				local target = expressions.parsePrimaryForTarget(state)
				if not target then
					state:raise("Invalid comprehension target")
				end
				setComprehensionTargetContext(target :: Expr)
				state:consume("IN", "Expected 'in' in comprehension")
				local iterExpr = expressions.parse(state)
				local filters: { Expr } = {}
				while state.current and state.current.type == "IF" do
					state:advance()
					local ifExpr = expressions.parse(state)
					table.insert(filters, ifExpr)
				end
				table.insert(gens, {
					target = target :: Expr,
					iter = iterExpr,
					ifs = filters,
					is_async = false,
				})
			end
			if #gens == 0 then
				state:raise("Expected comprehension generator")
			end
			return gens
		end

		local firstElement = parseListElement()

		if state.current and state.current.type == "FOR" then
			if firstElement.type == "Starred" then
				state:raise("Starred expression not allowed in list comprehension")
			end
			local generators = parseComprehensionGenerators()
			state:consume("RSQB", "Expected ']' to close list comprehension")
			local listComp: Expr = {
				type = "ListComp",
				elt = firstElement,
				generators = generators,
				lineno = current.line,
				col_offset = current.column,
			}
			return postfix.parse(state, listComp, expressions.parse)
		end

		local elts: { Expr } = { firstElement }
		while state.current and state.current.type ~= "RSQB" do
			if state.current.type == "COMMA" then
				state:advance()
				if state.current and state.current.type == "RSQB" then
					break
				end
				local nextElt = parseListElement()
				table.insert(elts, nextElt)
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
