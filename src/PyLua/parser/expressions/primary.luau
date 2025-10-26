local tokens = require("../../tokens")
local nodes = require("../../ast/nodes")
local postfix = require("../postfix")

export type Token = tokens.Token
export type Expr = nodes.Expr

export type PrimaryDeps = {
	postfix: typeof(postfix),
	prefixContains: (prefix: string?, flag: string) -> boolean,
	makeStringConstant: (token: Token) -> Expr,
	foldConcat: (parts: { Expr }, token: Token) -> Expr,
	parseExpression: (state: any) -> Expr,
	parseFStringLiteral: (token: Token, state: any) -> Expr,
}

local function createPrimaryModule(deps: PrimaryDeps)
	local postfixModule = deps.postfix
	local prefixContains = deps.prefixContains
	local makeStringConstant = deps.makeStringConstant
	local foldConcat = deps.foldConcat
	local parseExpression = deps.parseExpression
	local parseFStringLiteral = deps.parseFStringLiteral

	local parsePrimaryForTarget: (state: any) -> Expr?

	local function parsePrimary(state: any): Expr
		local currentOpt: Token? = state.current
		if not currentOpt then
			state:raise("Unexpected end of input in expression")
		end
		local current: Token = currentOpt :: Token
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
			return postfixModule.parse(state, node, parseExpression)
		end
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
			return postfixModule.parse(state, node, parseExpression)
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
			return postfixModule.parse(state, node, parseExpression)
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
			return postfixModule.parse(state, node, parseExpression)
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
			return postfixModule.parse(state, node, parseExpression)
		end
		if current.type == "NAME" then
			state:advance()
			local node: Expr = {
				type = "Name",
				id = current.value,
				ctx = "Load",
				lineno = current.line,
				col_offset = current.column,
			}
			return postfixModule.parse(state, node, parseExpression)
		end
		if current.type == "LSQB" then
			state:advance()
			if state.current and state.current.type == "RSQB" then
				state:advance()
				local emptyList: Expr = {
					type = "List",
					elts = {},
					ctx = "Load",
					lineno = current.line,
					col_offset = current.column,
				}
				return postfixModule.parse(state, emptyList, parseExpression)
			end

			local function parseListElement(): Expr
				if not state.current then
					state:raise("Expected expression in list literal")
				end
				if state.current.type == "STAR" then
					state:advance()
					local starredValue = parseExpression(state)
					return {
						type = "Starred",
						value = starredValue,
						ctx = "Load",
						lineno = starredValue.lineno,
						col_offset = starredValue.col_offset,
					}
				end
				return parseExpression(state)
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
					local target = parsePrimaryForTarget(state)
					if not target then
						state:raise("Invalid comprehension target")
					end
					setComprehensionTargetContext(target :: Expr)
					state:consume("IN", "Expected 'in' in comprehension")
					local iterExpr = parseExpression(state)
					local filters: { Expr } = {}
					while state.current and state.current.type == "IF" do
						state:advance()
						local ifExpr = parseExpression(state)
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
				return postfixModule.parse(state, listComp, parseExpression)
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
			local listNode: Expr = {
				type = "List",
				elts = elts,
				ctx = "Load",
				lineno = current.line,
				col_offset = current.column,
			}
			return postfixModule.parse(state, listNode, parseExpression)
		end
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
					local unpackExpr = parseExpression(state)
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
						local starredInner = parseExpression(state)
						firstExpr = {
							type = "Starred",
							value = starredInner,
							ctx = "Load",
							lineno = starredInner.lineno,
							col_offset = starredInner.col_offset,
						}
					else
						firstExpr = parseExpression(state)
					end
					if state.current and state.current.type == "COLON" then
						isDict = true
						state:advance()
						local valueExpr = parseExpression(state)
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
				node = {
					type = "Dict",
					keys = {},
					values = {},
					lineno = current.line,
					col_offset = current.column,
				}
			elseif isDict then
				node = {
					type = "Dict",
					keys = keys,
					values = values,
					lineno = current.line,
					col_offset = current.column,
				}
			else
				node = {
					type = "Set",
					elts = elts,
					lineno = current.line,
					col_offset = current.column,
				}
			end
			return postfixModule.parse(state, node, parseExpression)
		end
		if current.type == "LPAR" then
			state:advance()
			if state.current and state.current.type == "RPAR" then
				state:advance()
				local tupleNode: Expr = {
					type = "Tuple",
					elts = {},
					ctx = "Load",
					lineno = current.line,
					col_offset = current.column,
				}
				return postfixModule.parse(state, tupleNode, parseExpression)
			end
			local elements: { Expr } = {}
			local first: Expr
			if state.current and state.current.type == "STAR" then
				state:advance()
				local starredInner = parseExpression(state)
				first = {
					type = "Starred",
					value = starredInner,
					ctx = "Load",
					lineno = starredInner.lineno,
					col_offset = starredInner.col_offset,
				}
			else
				first = parseExpression(state)
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
						local starredInner = parseExpression(state)
						nextExpr = {
							type = "Starred",
							value = starredInner,
							ctx = "Load",
							lineno = starredInner.lineno,
							col_offset = starredInner.col_offset,
						}
					else
						nextExpr = parseExpression(state)
					end
					table.insert(elements, nextExpr)
				end
				state:consume("RPAR", "Expected ')' to close tuple")
				local tupleNode: Expr = {
					type = "Tuple",
					elts = elements,
					ctx = "Load",
					lineno = first.lineno,
					col_offset = first.col_offset,
				}
				return postfixModule.parse(state, tupleNode, parseExpression)
			else
				state:consume("RPAR", "Expected ')' after expression")
				return postfixModule.parse(state, first, parseExpression)
			end
		end

		state:raise("Unexpected token in expression: " .. current.type)
		return {
			type = "Constant",
			value = nil,
			kind = nil,
			lineno = current.line,
			col_offset = current.column,
		}
	end

	parsePrimaryForTarget = function(state: any): Expr?
		local tok: Token? = state.current
		if not tok or tok.type ~= "NAME" then
			return nil
		end
		local savedPos = state.pos
		local savedTok = tok
		local node = parsePrimary(state)
		return node
	end

	return {
		parsePrimary = parsePrimary,
		parsePrimaryForTarget = parsePrimaryForTarget,
	}
end

return {
	new = createPrimaryModule,
}
