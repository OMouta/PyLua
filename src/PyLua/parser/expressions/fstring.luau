local tokens = require("../../tokens")
local nodes = require("../../ast/nodes")

export type Token = tokens.Token
export type Expr = nodes.Expr

export type FStringDeps = {
	lexer: any,
	wrapCall: (funcName: string, argList: { Expr }, baseNode: Expr, token: Token) -> Expr,
	foldConcat: (parts: { Expr }, token: Token) -> Expr,
	parseExpression: (state: any) -> Expr,
}

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

local function createEmbeddedExpressionParser(deps: FStringDeps)
	local lexer = deps.lexer
	local parseExpression = deps.parseExpression

	local function parseEmbeddedExpression(exprText: string, state: any, token: Token): Expr
		local exprTokens = lexer.tokenize(exprText)
		local subState = makeSubState(exprTokens, state)
		local exprNode = parseExpression(subState)
		while subState.current and (subState.current.type == "NEWLINE" or subState.current.type == "ENDMARKER") do
			subState:advance()
		end
		if subState.current then
			state:raise("Unexpected token after expression in f-string")
		end
		return exprNode
	end

	return parseEmbeddedExpression
end

local function buildFormattedValue(
	exprNode: Expr,
	conversion: string?,
	formatSpec: string?,
	token: Token,
	state: any,
	deps: FStringDeps
): Expr
	local converted = exprNode
	if conversion == "s" then
		converted = deps.wrapCall("str", { converted }, exprNode, token)
	elseif conversion == "r" then
		converted = deps.wrapCall("repr", { converted }, exprNode, token)
	elseif conversion == "a" then
		converted = deps.wrapCall("ascii", { converted }, exprNode, token)
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
		converted = deps.wrapCall("format", { converted, specConst }, converted, token)
	elseif conversion == nil then
		converted = deps.wrapCall("str", { converted }, exprNode, token)
	end

	return converted
end

local function createFormattedSectionParser(deps: FStringDeps)
	local parseEmbeddedExpression = createEmbeddedExpressionParser(deps)

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

		local formatted = buildFormattedValue(exprNode, conversion, formatSpecText, token, state, deps)
		return formatted, i + 1
	end

	return parseFormattedSection
end

local function createFStringParser(deps: FStringDeps)
	local parseFormattedSection = createFormattedSectionParser(deps)

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
				local nextCh = i < len and string.sub(content, i + 1, i + 1) or nil
				if nextCh == "{" then
					table.insert(literalBuffer, "{")
					i += 2
				else
					flushLiteral()
					local expr, nextIndex = parseFormattedSection(content, i, state, token)
					table.insert(values, expr)
					i = nextIndex
				end
			elseif ch == "}" then
				local nextCh = i < len and string.sub(content, i + 1, i + 1) or nil
				if nextCh == "}" then
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

		return deps.foldConcat(values, token)
	end

	return {
		parseFStringLiteral = parseFStringLiteral,
	}
end

return {
	new = createFStringParser,
}
