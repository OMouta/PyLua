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

-- Detect if current position starts a Python string literal (quote or prefix+quote)
local function isStringStart(state: LexerState): boolean
	local c0 = peek(state)
	if not c0 then
		return false
	end
	if c0 == '"' or c0 == "'" then
		return true
	end
	local lc0 = string.lower(c0)
	if lc0 ~= "r" and lc0 ~= "f" then
		return false
	end
	local c1 = peek(state, 1)
	if not c1 then
		return false
	end
	if c1 == '"' or c1 == "'" then
		return true
	end
	local lc1 = string.lower(c1)
	if (lc1 == "r" or lc1 == "f") then
		local c2 = peek(state, 2)
		if c2 == '"' or c2 == "'" then
			return true
		end
	end
	return false
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
	local startLine = state.line
	-- Detect optional string prefix (r, f, fr, rf; case-insensitive like Python)
	local prefix = ""
	while true do
		local c = peek(state)
		if not c then break end
		local lc = string.lower(c)
		if lc == "r" or lc == "f" then
			prefix ..= lc
			advance(state)
		else
			break
		end
	end

	-- Opening quote
	local quote = advance(state) :: string
	if quote ~= '"' and quote ~= "'" then
		-- Not actually a string; error token
		return tokens.newToken("ERRORTOKEN", quote, startLine, startCol)
	end

	-- Triple quote?
	local isTriple = false
	if peek(state) == quote and peek(state, 1) == quote then
		isTriple = true
		advance(state)
		advance(state)
	end

	-- Accumulate raw content (without delimiters)
	local content = ""
	while peek(state) do
		local ch = peek(state) :: string
		if isTriple then
			if ch == quote and peek(state, 1) == quote and peek(state, 2) == quote then
				advance(state); advance(state); advance(state)
				break
			else
				content ..= advance(state) :: string
			end
		else
			if ch == quote then
				advance(state)
				break
			elseif ch == "\\" then
				-- Keep escapes verbatim here; decoding can occur later if needed (non-raw)
				content ..= advance(state) :: string
				if peek(state) then content ..= advance(state) :: string end
			elseif ch == "\n" then
				return tokens.newToken("ERRORTOKEN", "Unterminated string", startLine, startCol)
			else
				content ..= advance(state) :: string
			end
		end
	end

	local lexeme
	if isTriple then
		lexeme = (prefix or "") .. quote .. quote .. quote .. content .. quote .. quote .. quote
	else
		lexeme = (prefix or "") .. quote .. content .. quote
	end
	local extras = { stringPrefix = prefix ~= "" and prefix or nil, isTriple = isTriple, stringContent = content }
	return tokens.newToken("STRING", lexeme, startLine, startCol, state.line, state.column - 1, extras)
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
		if state.atLineStart and peek(state) then
			local char = peek(state) :: string
			if tokens.isWhitespace(char) then
				-- Line has indentation - count it
				local indentTokens = handleIndentation(state)
				for _, token in ipairs(indentTokens) do
					table.insert(tokenList, token)
				end
			else
				-- Line starts at column 0 - check if we need DEDENTs
				local currentIndent = state.indentStack[#state.indentStack]
				if currentIndent > 0 then
					-- We're at indentation level 0, emit DEDENTs as needed
					local indentTokens: { Token } = {}
					while #state.indentStack > 1 and state.indentStack[#state.indentStack] > 0 do
						table.remove(state.indentStack)
						table.insert(indentTokens, tokens.newToken("DEDENT", "", state.line, 1))
					end
					for _, token in ipairs(indentTokens) do
						table.insert(tokenList, token)
					end
				end
				skipWhitespace(state)
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

		-- Strings (quote or valid prefix+quote)
		elseif isStringStart(state) then
			table.insert(tokenList, tokenizeString(state))

		-- Identifiers and keywords
		elseif tokens.isIdentifierStart(char) then
			table.insert(tokenList, tokenizeIdentifier(state))

		-- Comments: consume until newline; do not emit COMMENT tokens for parser
		elseif char == "#" then
			advance(state) -- consume '#'
			while peek(state) and peek(state) ~= "\n" do
				advance(state)
			end

		-- Newlines
		elseif char == "\n" then
			-- Capture current coordinates before advancing so NEWLINE points to the line/col where '\n' occurs
			local ln = state.line
			local col = state.column
			advance(state)
			table.insert(tokenList, tokens.newToken("NEWLINE", "\n", ln, col))

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
			elseif ch == "@" then
				tokenType = "AT"
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
