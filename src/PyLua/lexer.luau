--!strict
-- PyLua Lexer - Python-compliant tokenization
-- Phase 1.2 - Comprehensive Python tokenization

local Lexer = {}

local tokens = require("./tokens")
type Token = tokens.Token
type TokenType = tokens.TokenType

-- Lexer state
type LexerState = {
	source: string,
	pos: number,
	line: number,
	column: number,
	length: number,
	indentStack: { number },
	atLineStart: boolean,
}

-- Create a new lexer state
local function newLexerState(source: string): LexerState
	return {
		source = source,
		pos = 1,
		line = 1,
		column = 1,
		length = #source,
		indentStack = { 0 }, -- Start with 0 indentation
		atLineStart = true,
	}
end

-- Peek at current character without advancing
local function peek(state: LexerState, offset: number?): string?
	local pos = state.pos + (offset or 0)
	if pos <= state.length then
		return string.sub(state.source, pos, pos)
	end
	return nil
end

-- Advance position and return current character
local function advance(state: LexerState): string?
	if state.pos <= state.length then
		local char = string.sub(state.source, state.pos, state.pos)
		state.pos = state.pos + 1

		if char == "\n" then
			state.line = state.line + 1
			state.column = 1
			state.atLineStart = true
		else
			state.column = state.column + 1
			if not tokens.isWhitespace(char) then
				state.atLineStart = false
			end
		end

		return char
	end
	return nil
end

-- Skip whitespace (but not newlines)
local function skipWhitespace(state: LexerState)
	while peek(state) and tokens.isWhitespace(peek(state) :: string) do
		advance(state)
	end
end

-- Tokenize a number (integer or float)
local function tokenizeNumber(state: LexerState): Token
	local startPos = state.pos
	local startCol = state.column
	local value = ""

	-- Handle different number formats
	local char = peek(state)

	-- Binary, octal, hex prefixes
	if char == "0" then
		value = value .. advance(state) :: string
		local nextChar = peek(state)

		if nextChar == "b" or nextChar == "B" then
			-- Binary number
			value = value .. advance(state) :: string
			while peek(state) and (peek(state) == "0" or peek(state) == "1") do
				value = value .. advance(state) :: string
			end
		elseif nextChar == "o" or nextChar == "O" then
			-- Octal number
			value = value .. advance(state) :: string
			while peek(state) and peek(state) >= "0" and peek(state) <= "7" do
				value = value .. advance(state) :: string
			end
		elseif nextChar == "x" or nextChar == "X" then
			-- Hexadecimal number
			value = value .. advance(state) :: string
			while
				peek(state)
				and (
					tokens.isDigit(peek(state) :: string)
					or (peek(state) >= "a" and peek(state) <= "f")
					or (peek(state) >= "A" and peek(state) <= "F")
				)
			do
				value = value .. advance(state) :: string
			end
		end
	end

	-- Regular decimal digits
	while peek(state) and tokens.isDigit(peek(state) :: string) do
		value = value .. advance(state) :: string
	end

	-- Decimal point
	if peek(state) == "." and peek(state, 1) and tokens.isDigit(peek(state, 1) :: string) then
		value = value .. advance(state) :: string -- consume '.'
		while peek(state) and tokens.isDigit(peek(state) :: string) do
			value = value .. advance(state) :: string
		end
	end

	-- Scientific notation
	if peek(state) == "e" or peek(state) == "E" then
		value = value .. advance(state) :: string
		if peek(state) == "+" or peek(state) == "-" then
			value = value .. advance(state) :: string
		end
		while peek(state) and tokens.isDigit(peek(state) :: string) do
			value = value .. advance(state) :: string
		end
	end

	return tokens.newToken("NUMBER", value, state.line, startCol, state.line, state.column - 1)
end

-- Tokenize a string literal
local function tokenizeString(state: LexerState): Token
	local startCol = state.column
	local quote = advance(state) :: string -- consume opening quote
	local value = quote
	local isTripleQuote = false

	-- Check for triple quotes
	if peek(state) == quote and peek(state, 1) == quote then
		isTripleQuote = true
		value = value .. advance(state) :: string .. advance(state) :: string
	end

	-- Consume string content
	while peek(state) do
		local char = peek(state) :: string

		if isTripleQuote then
			-- Triple quote string
			if char == quote and peek(state, 1) == quote and peek(state, 2) == quote then
				value = value .. advance(state) :: string .. advance(state) :: string .. advance(state) :: string
				break
			else
				value = value .. advance(state) :: string
			end
		else
			-- Regular string
			if char == quote then
				value = value .. advance(state) :: string
				break
			elseif char == "\\" then
				-- Escape sequence
				value = value .. advance(state) :: string
				if peek(state) then
					value = value .. advance(state) :: string
				end
			elseif char == "\n" then
				-- Unterminated string
				return tokens.newToken("ERRORTOKEN", value, state.line, startCol)
			else
				value = value .. advance(state) :: string
			end
		end
	end

	return tokens.newToken("STRING", value, state.line, startCol, state.line, state.column - 1)
end

-- Tokenize an identifier or keyword
local function tokenizeIdentifier(state: LexerState): Token
	local startCol = state.column
	local value = ""

	-- First character must be letter or underscore
	if peek(state) and tokens.isIdentifierStart(peek(state) :: string) then
		value = value .. advance(state) :: string
	end

	-- Subsequent characters can be letters, digits, or underscores
	while peek(state) and tokens.isIdentifierCont(peek(state) :: string) do
		value = value .. advance(state) :: string
	end

	-- Check if it's a keyword
	local tokenType: TokenType = (tokens.isKeyword(value) or "NAME") :: TokenType

	return tokens.newToken(tokenType, value, state.line, startCol, state.line, state.column - 1)
end

-- Handle indentation at the start of a line
local function handleIndentation(state: LexerState): { Token }
	local indentTokens: { Token } = {}
	local indentLevel = 0

	-- Count leading whitespace
	while peek(state) and tokens.isWhitespace(peek(state) :: string) do
		local char = advance(state) :: string
		if char == " " then
			indentLevel = indentLevel + 1
		elseif char == "\t" then
			indentLevel = indentLevel + 8 -- Tab = 8 spaces
		end
	end

	local currentIndent = state.indentStack[#state.indentStack]

	if indentLevel > currentIndent then
		-- Increased indentation
		table.insert(state.indentStack, indentLevel)
		table.insert(indentTokens, tokens.newToken("INDENT", "", state.line, 1))
	elseif indentLevel < currentIndent then
		-- Decreased indentation
		while #state.indentStack > 1 and state.indentStack[#state.indentStack] > indentLevel do
			table.remove(state.indentStack)
			table.insert(indentTokens, tokens.newToken("DEDENT", "", state.line, 1))
		end

		-- Check for indentation error
		if state.indentStack[#state.indentStack] ~= indentLevel then
			table.insert(indentTokens, tokens.newToken("ERRORTOKEN", "IndentationError", state.line, 1))
		end
	end

	return indentTokens
end

-- Main tokenization function
function Lexer.tokenize(source: string): { Token }
	local state = newLexerState(source)
	local tokenList: { Token } = {}

	while state.pos <= state.length do
		-- Handle indentation at line start
		if state.atLineStart and peek(state) and tokens.isWhitespace(peek(state) :: string) then
			local indentTokens = handleIndentation(state)
			for _, token in ipairs(indentTokens) do
				table.insert(tokenList, token)
			end
		else
			skipWhitespace(state)
		end

		local char = peek(state)
		if not char then
			break
		end

		-- Numbers
		if tokens.isDigit(char) then
			table.insert(tokenList, tokenizeNumber(state))

		-- Strings
		elseif char == "'" or char == '"' then
			table.insert(tokenList, tokenizeString(state))

		-- Identifiers and keywords
		elseif tokens.isIdentifierStart(char) then
			table.insert(tokenList, tokenizeIdentifier(state))

		-- Comments
		elseif char == "#" then
			local startCol = state.column
			local comment = ""
			advance(state) -- consume #

			while peek(state) and peek(state) ~= "\n" do
				comment = comment .. advance(state) :: string
			end

			table.insert(tokenList, tokens.newToken("COMMENT", "#" .. comment, state.line, startCol))

		-- Newlines
		elseif char == "\n" then
			table.insert(tokenList, tokens.newToken("NEWLINE", advance(state) :: string, state.line - 1, state.column))

		-- Two-character operators
		elseif char == "=" and peek(state, 1) == "=" then
			advance(state)
			advance(state)
			table.insert(tokenList, tokens.newToken("EQEQUAL", "==", state.line, state.column - 2))
		elseif char == "!" and peek(state, 1) == "=" then
			advance(state)
			advance(state)
			table.insert(tokenList, tokens.newToken("NOTEQUAL", "!=", state.line, state.column - 2))
		elseif char == "<" and peek(state, 1) == "=" then
			advance(state)
			advance(state)
			table.insert(tokenList, tokens.newToken("LESSEQUAL", "<=", state.line, state.column - 2))
		elseif char == ">" and peek(state, 1) == "=" then
			advance(state)
			advance(state)
			table.insert(tokenList, tokens.newToken("GREATEREQUAL", ">=", state.line, state.column - 2))
		elseif char == "*" and peek(state, 1) == "*" then
			advance(state)
			advance(state)
			table.insert(tokenList, tokens.newToken("DOUBLESTAR", "**", state.line, state.column - 2))
		elseif char == "/" and peek(state, 1) == "/" then
			advance(state)
			advance(state)
			table.insert(tokenList, tokens.newToken("DOUBLESLASH", "//", state.line, state.column - 2))
		elseif char == "<" and peek(state, 1) == "<" then
			advance(state)
			advance(state)
			table.insert(tokenList, tokens.newToken("LEFTSHIFT", "<<", state.line, state.column - 2))
		elseif char == ">" and peek(state, 1) == ">" then
			advance(state)
			advance(state)
			table.insert(tokenList, tokens.newToken("RIGHTSHIFT", ">>", state.line, state.column - 2))

		-- Single-character tokens
		else
			local startCol = state.column
			local ch = advance(state) :: string
			local tokenType: TokenType

			if ch == "+" then
				tokenType = "PLUS"
			elseif ch == "-" then
				tokenType = "MINUS"
			elseif ch == "*" then
				tokenType = "STAR"
			elseif ch == "/" then
				tokenType = "SLASH"
			elseif ch == "%" then
				tokenType = "PERCENT"
			elseif ch == "|" then
				tokenType = "VBAR"
			elseif ch == "&" then
				tokenType = "AMPER"
			elseif ch == "^" then
				tokenType = "CIRCUMFLEX"
			elseif ch == "~" then
				tokenType = "TILDE"
			elseif ch == "<" then
				tokenType = "LESS"
			elseif ch == ">" then
				tokenType = "GREATER"
			elseif ch == "=" then
				tokenType = "EQUAL"
			elseif ch == "@" then
				tokenType = "AT"
			elseif ch == "(" then
				tokenType = "LPAR"
			elseif ch == ")" then
				tokenType = "RPAR"
			elseif ch == "[" then
				tokenType = "LSQB"
			elseif ch == "]" then
				tokenType = "RSQB"
			elseif ch == "{" then
				tokenType = "LBRACE"
			elseif ch == "}" then
				tokenType = "RBRACE"
			elseif ch == "," then
				tokenType = "COMMA"
			elseif ch == ":" then
				tokenType = "COLON"
			elseif ch == ";" then
				tokenType = "SEMICOLON"
			elseif ch == "." then
				tokenType = "DOT"
			else
				tokenType = "ERRORTOKEN"
			end

			table.insert(tokenList, tokens.newToken(tokenType, ch, state.line, startCol))
		end
	end

	-- Add final DEDENT tokens if needed
	while #state.indentStack > 1 do
		table.remove(state.indentStack)
		table.insert(tokenList, tokens.newToken("DEDENT", "", state.line, 1))
	end

	-- End marker
	table.insert(tokenList, tokens.newToken("ENDMARKER", "", state.line, state.column))

	return tokenList
end

return Lexer
