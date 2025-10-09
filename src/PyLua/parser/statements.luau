local nodes = require("../ast/nodes")
local precedence = require("./precedence")
local expressions = require("./expressions")

export type Expr = nodes.Expr
export type Stmt = nodes.Stmt

local statements = {}

-- Helper to recursively parse assignment targets (including nested tuples)
local function parseForTarget(state: any): Expr
	if state.current and state.current.type == "LPAR" then
		-- Parenthesized tuple
		local lparToken = state.current
		state:advance() -- consume LPAR
		
		local elements: { Expr } = {}
		if state.current and state.current.type ~= "RPAR" then
			-- Parse first element (recursively handles nested tuples)
			table.insert(elements, parseForTarget(state))
			
			-- Parse remaining elements
			while state.current and state.current.type == "COMMA" do
				state:advance() -- consume COMMA
				if state.current and state.current.type == "RPAR" then
					break -- trailing comma
				end
				table.insert(elements, parseForTarget(state))
			end
		end
		
		state:consume("RPAR", "Expected ')' to close tuple")
		
		-- Create tuple node
		return {
			type = "Tuple",
			elts = elements,
			ctx = "Load",
			lineno = lparToken.line,
			col_offset = lparToken.column,
		}
	else
		-- Simple name or name with subscript/attribute
		local targetOpt = expressions.parsePrimaryForTarget(state)
		if not targetOpt then
			state:raise("Invalid for target element")
		end
		return targetOpt :: Expr
	end
end

local function assignmentTarget(expr: Expr): Expr
	if expr.type == "Name" or expr.type == "Attribute" or expr.type == "Subscript" then
		(expr :: any).ctx = "Store"
	elseif expr.type == "Tuple" then
		-- Recursively mark tuple elements as store targets
		(expr :: any).ctx = "Store"
		for _, elt in ipairs((expr :: any).elts) do
			assignmentTarget(elt)
		end
	end
	return expr
end

-- Parse a simple statement (assignment, augassign, expression, return)
function statements.parseSimple(state: any): Stmt
	local current = state.current
	if not current then
		state:raise("Unexpected end of input in statement")
	end
	if current.type == "RETURN" then
		state:advance()
		local value: Expr? = nil
		if
			state.current
			and state.current.type ~= "NEWLINE"
			and state.current.type ~= "ENDMARKER"
			and state.current.type ~= "DEDENT"
		then
			value = expressions.parse(state)
		end
		return { type = "Return", value = value, lineno = current.line, col_offset = current.column }
	elseif current.type == "BREAK" then
		state:advance()
		return { type = "Break", lineno = current.line, col_offset = current.column }
	elseif current.type == "CONTINUE" then
		state:advance()
		return { type = "Continue", lineno = current.line, col_offset = current.column }
	elseif current.type == "PASS" then
		state:advance()
		return { type = "Pass", lineno = current.line, col_offset = current.column }
	end
	-- Attempt target-only parse for assignment/augassign
	local savePos = state.pos
	local saveCurrent = current
	local targetCandidate = expressions.parsePrimaryForTarget(state)
	if targetCandidate then
		local afterTarget = state.current
		if afterTarget and afterTarget.type == "EQUAL" then
			state:advance()
			local value = expressions.parse(state)
			local target = assignmentTarget(targetCandidate)
			return {
				type = "Assign",
				targets = { target },
				value = value,
				lineno = target.lineno,
				col_offset = target.col_offset,
			}
		elseif afterTarget then
			local opTok = afterTarget
			local nextTok = state:lookahead(1)
			local opMap = precedence.BINOP_MAP
			if nextTok and nextTok.type == "EQUAL" and opMap[opTok.type] then
				state:advance()
				state:advance()
				local value = expressions.parse(state)
				local target = assignmentTarget(targetCandidate)
				return {
					type = "AugAssign",
					target = target,
					op = opMap[opTok.type],
					value = value,
					lineno = target.lineno,
					col_offset = target.col_offset,
				}
			end
		end
		state.pos = savePos
		state.current = saveCurrent
	else
		state.pos = savePos
		state.current = saveCurrent
	end
	local expr = expressions.parse(state)
	return { type = "Expr", value = expr, lineno = expr.lineno, col_offset = expr.col_offset }
end

local function parseSuiteAfterColon(state: any): { Stmt }
	local body: { Stmt } = {}

	if state.current and state.current.type == "NEWLINE" then
		-- Multi-line suite
		state:advance()
		if state.current and state.current.type == "INDENT" then
			state:advance()
		end

		while
			state.current
			and state.current.type ~= "ENDMARKER"
			and state.current.type ~= "DEDENT"
			and state.current.type ~= "ELIF"
			and state.current.type ~= "ELSE"
		do
			local stmt = statements.parse(state)
			table.insert(body, stmt)
			while state.current and state.current.type == "NEWLINE" do
				state:advance()
			end
		end

		if state.current and state.current.type == "DEDENT" then
			state:advance()
		end
	else
		-- Single-line suite: parse only one statement
		local stmt = statements.parse(state)
		table.insert(body, stmt)
	end

	return body
end

function statements.parseCompound(state: any): Stmt
	local current = state.current
	if not current then
		state:raise("Unexpected end of input in compound statement")
	end
	if current.type == "IF" then
		state:advance()
		local test = expressions.parse(state)
		state:consume("COLON", "Expected ':' after if condition")
		local body = parseSuiteAfterColon(state)

		local ifNode = {
			type = "If",
			test = test,
			body = body,
			orelse = {},
			lineno = current.line,
			col_offset = current.column,
		}

		local lastIf = ifNode

		-- Handle chained elif clauses by nesting If nodes in orelse lists
		while state.current and state.current.type == "ELIF" do
			local elifToken = state.current
			state:advance()
			local elifTest = expressions.parse(state)
			state:consume("COLON", "Expected ':' after elif condition")
			local elifBody = parseSuiteAfterColon(state)
			local elifNode = {
				type = "If",
				test = elifTest,
				body = elifBody,
				orelse = {},
				lineno = elifToken.line,
				col_offset = elifToken.column,
			}
			lastIf.orelse = { elifNode }
			lastIf = elifNode
		end

		-- Handle final else clause (binds to last if/elif in chain)
		if state.current and state.current.type == "ELSE" then
			state:advance()
			state:consume("COLON", "Expected ':' after else")
			lastIf.orelse = parseSuiteAfterColon(state)
		end

		return ifNode
	end
	if current.type == "WHILE" then
		state:advance()
		local test = expressions.parse(state)
		state:consume("COLON", "Expected ':' after while condition")
		local body = parseSuiteAfterColon(state)
		return {
			type = "While",
			test = test,
			body = body,
			orelse = {},
			lineno = current.line,
			col_offset = current.column,
		}
	end
	if current.type == "FOR" then
		state:advance()
		-- Parse the target - can be a Name or a Tuple for destructuring
		local target: Expr
		
		-- Parse the first part of the target
		target = parseForTarget(state)
		
		-- Check if there's a comma, making it an implicit tuple
		if state.current and state.current.type == "COMMA" then
			-- Implicit tuple without parens: for x, y in items: or for (a, b), c in items:
			local elements = { target }
			while state.current and state.current.type == "COMMA" do
				state:advance()
				-- Check if we hit 'in' (trailing comma case)
				if state.current and state.current.type == "IN" then
					break
				end
				table.insert(elements, parseForTarget(state))
			end
			-- Create tuple node
			target = {
				type = "Tuple",
				elts = elements,
				ctx = "Load",
				lineno = elements[1].lineno,
				col_offset = elements[1].col_offset,
			}
		end
		
		-- Mark target as Store context before consuming 'in'
		target = assignmentTarget(target)
		
		state:consume("IN", "Expected 'in' after for target")
		local iter = expressions.parse(state)
		state:consume("COLON", "Expected ':' after for clause")
		local body = parseSuiteAfterColon(state)
		return {
			type = "For",
			target = target,
			iter = iter,
			body = body,
			orelse = {},
			lineno = current.line,
			col_offset = current.column,
		}
	end
	if current.type == "TRY" then
		local tryToken = current
		state:advance()
		state:consume("COLON", "Expected ':' after try")
		local body = parseSuiteAfterColon(state)

		local handlers = {}
		local sawExcept = false
		while state.current and state.current.type == "EXCEPT" do
			local exceptToken = state.current
			state:advance()
			local handlerExpr: Expr? = nil
			if state.current and state.current.type ~= "COLON" then
				handlerExpr = expressions.parse(state)
			end
			sawExcept = true

			local aliasName: string? = nil
			if state.current and state.current.type == "AS" then
				state:advance()
				local nameToken = state:consume("NAME", "Expected name after 'as'")
				aliasName = nameToken.value
			end

			state:consume("COLON", "Expected ':' after except clause")
			local handlerBody = parseSuiteAfterColon(state)

			table.insert(handlers, {
				type = "ExceptHandler",
				lineno = exceptToken.line,
				col_offset = exceptToken.column,
				end_lineno = nil,
				end_col_offset = nil,
				body = handlerBody,
				expr = handlerExpr,
				name = aliasName,
			})
		end

		local finalbody: { Stmt } = {}
		local nextToken = state.current and state.current.type or nil
		if not sawExcept and nextToken ~= "FINALLY" then
			state:raise("Expected at least one except or finally clause for try statement")
		end

		for i, handler in ipairs(handlers) do
			if (handler :: any).expr == nil and i < #handlers then
				state:raise("Bare 'except' must be the final handler")
			end
		end

		local orelse: { Stmt } = {}
		if state.current and state.current.type == "ELSE" then
			state:advance()
			state:consume("COLON", "Expected ':' after else")
			if not sawExcept then
				state:raise("'else' clause is only allowed when at least one except handler is present")
			end
			orelse = parseSuiteAfterColon(state)
		end

		if state.current and state.current.type == "FINALLY" then
			state:advance()
			state:consume("COLON", "Expected ':' after finally")
			finalbody = parseSuiteAfterColon(state)
		end

		if not sawExcept and #finalbody == 0 then
			state:raise("try statement requires except or finally clause")
		end

		return {
			type = "Try",
			body = body,
			handlers = handlers,
			orelse = orelse,
			finalbody = finalbody,
			lineno = tryToken.line,
			col_offset = tryToken.column,
		}
	end
	if current.type == "DEF" then
		state:advance()
		local nameToken = state:consume("NAME", "Expected function name after 'def'")
		local name = nameToken.value
		state:consume("LPAR", "Expected '(' after function name")

		-- Parse function arguments
		local args =
			{ posonlyargs = {}, args = {}, vararg = nil, kwonlyargs = {}, kw_defaults = {}, kwarg = nil, defaults = {} }

		-- Parse parameter list
		while state.current and state.current.type ~= "RPAR" do
			local paramToken = state:consume("NAME", "Expected parameter name")
			local param = {
				arg = paramToken.value,
				annotation = nil, -- No type annotations for now
				lineno = paramToken.line,
				col_offset = paramToken.column,
			}
			table.insert(args.args, param)

			-- Check for default value (e.g., param=value)
			if state.current and state.current.type == "EQUAL" then
				state:advance() -- consume '='
				local defaultExpr = expressions.parse(state)
				table.insert(args.defaults, defaultExpr)
			else
				-- If no default for this parameter, we may need to track it
				-- In Python, once you have a default, all following params must have defaults
				-- For now, only add to defaults array when we actually see '='
			end

			-- Check for comma or end
			if state.current and state.current.type == "COMMA" then
				state:advance() -- consume comma
				-- If next token is RPAR, we have a trailing comma which is fine
				if state.current and state.current.type == "RPAR" then
					break
				end
			elseif state.current and state.current.type == "RPAR" then
				break -- End of parameters
			else
				state:raise("Expected ',' or ')' after parameter")
			end
		end

		state:consume("RPAR", "Expected ')' after function arguments")
		state:consume("COLON", "Expected ':' after function signature")
		local body = parseSuiteAfterColon(state)
		return {
			type = "FunctionDef",
			name = name,
			args = args,
			body = body,
			decorator_list = {},
			returns = nil,
			lineno = current.line,
			col_offset = current.column,
		}
	end
	state:raise("Unknown compound statement: " .. current.type)
	error("unreachable")
end

function statements.parse(state: any): Stmt
	local current = state.current
	if not current then
		state:raise("Unexpected end of input in statement")
	end
	if
		current.type == "IF"
		or current.type == "WHILE"
		or current.type == "FOR"
		or current.type == "DEF"
		or current.type == "TRY"
	then
		return statements.parseCompound(state)
	end
	return statements.parseSimple(state)
end

return statements
