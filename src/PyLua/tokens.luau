local Tokens = {}

-- All Python token types (based on Python's token module)
export type TokenType =
	-- Literals
	"NUMBER"
	| "STRING"
	| "NAME"
	-- Operators
	| "PLUS"
	| "MINUS"
	| "STAR"
	| "SLASH"
	| "PERCENT"
	| "DOUBLESTAR"
	| "DOUBLESLASH"
	| "VBAR"
	| "AMPER"
	| "CIRCUMFLEX"
	| "LEFTSHIFT"
	| "RIGHTSHIFT"
	| "TILDE"
	| "LESS"
	| "GREATER"
	| "LESSEQUAL"
	| "GREATEREQUAL"
	| "EQEQUAL"
	| "NOTEQUAL"
	| "AT"
	-- Delimiters
	| "LPAR"
	| "RPAR"
	| "LSQB"
	| "RSQB"
	| "LBRACE"
	| "RBRACE"
	| "COMMA"
	| "COLON"
	| "SEMICOLON"
	| "DOT"
	| "ARROW"
	| "ELLIPSIS"
	-- Assignment
	| "EQUAL"
	| "PLUSEQUAL"
	| "MINEQUAL"
	| "STAREQUAL"
	| "SLASHEQUAL"
	| "PERCENTEQUAL"
	| "AMPEREQUAL"
	| "VBAREQUAL"
	| "CIRCUMFLEXEQUAL"
	| "LEFTSHIFTEQUAL"
	| "RIGHTSHIFTEQUAL"
	| "DOUBLESTAREQUAL"
	| "DOUBLESLASHEQUAL"
	-- Special
	| "NEWLINE"
	| "INDENT"
	| "DEDENT"
	| "COMMENT"
	| "NL"
	| "ENDMARKER"
	| "ERRORTOKEN"
	-- Keywords (will be converted from NAME tokens)
	| "AND"
	| "AS"
	| "ASSERT"
	| "BREAK"
	| "CLASS"
	| "CONTINUE"
	| "DEF"
	| "DEL"
	| "ELIF"
	| "ELSE"
	| "EXCEPT"
	| "EXEC"
	| "FINALLY"
	| "FOR"
	| "FROM"
	| "GLOBAL"
	| "IF"
	| "IMPORT"
	| "IN"
	| "IS"
	| "LAMBDA"
	| "NOT"
	| "OR"
	| "PASS"
	| "PRINT"
	| "RAISE"
	| "RETURN"
	| "TRY"
	| "WHILE"
	| "WITH"
	| "YIELD"
	| "NONE"
	| "TRUE"
	| "FALSE"

-- Token structure
export type Token = {
	type: TokenType,
	value: string,
	line: number,
	column: number,
	endLine: number,
	endColumn: number,
	-- Optional fields for certain token kinds
	stringPrefix: string?, -- e.g. "r", "f", "fr", etc. for STRING tokens
	isTriple: boolean?, -- true for triple-quoted strings
	stringContent: string?, -- content-only body of STRING without delimiters
}

-- Python keywords
local KEYWORDS: { [string]: TokenType } = {
	["and"] = "AND",
	["as"] = "AS",
	["assert"] = "ASSERT",
	["break"] = "BREAK",
	["class"] = "CLASS",
	["continue"] = "CONTINUE",
	["def"] = "DEF",
	["del"] = "DEL",
	["elif"] = "ELIF",
	["else"] = "ELSE",
	["except"] = "EXCEPT",
	["exec"] = "EXEC",
	["finally"] = "FINALLY",
	["for"] = "FOR",
	["from"] = "FROM",
	["global"] = "GLOBAL",
	["if"] = "IF",
	["import"] = "IMPORT",
	["in"] = "IN",
	["is"] = "IS",
	["lambda"] = "LAMBDA",
	["not"] = "NOT",
	["or"] = "OR",
	["pass"] = "PASS",
	["raise"] = "RAISE",
	["return"] = "RETURN",
	["try"] = "TRY",
	["while"] = "WHILE",
	["with"] = "WITH",
	["yield"] = "YIELD",
	["None"] = "NONE",
	["True"] = "TRUE",
	["False"] = "FALSE",
}

-- Create a new token
function Tokens.newToken(
	tokenType: TokenType,
	value: string,
	line: number,
	column: number,
	endLine: number?,
	endColumn: number?,
	extras: { [string]: any }?
): Token
	local t: Token = {
		type = tokenType,
		value = value,
		line = line,
		column = column,
		endLine = endLine or line,
		endColumn = endColumn or ((#value > 0) and (column + #value - 1) or column),
	}
	if extras then
		for k, v in pairs(extras) do
			(t :: any)[k] = v
		end
	end
	return t
end

-- Check if a string is a Python keyword
function Tokens.isKeyword(name: string): TokenType?
	return KEYWORDS[name]
end

-- Check if character is a valid identifier start
function Tokens.isIdentifierStart(char: string): boolean
	local byte = string.byte(char)
	return (byte >= 65 and byte <= 90) -- A-Z
		or (byte >= 97 and byte <= 122) -- a-z
		or byte == 95 -- _
end

-- Check if character is a valid identifier continuation
function Tokens.isIdentifierCont(char: string): boolean
	local byte = string.byte(char)
	return Tokens.isIdentifierStart(char) or (byte >= 48 and byte <= 57) -- 0-9
end

-- Check if character is a digit
function Tokens.isDigit(char: string): boolean
	local byte = string.byte(char)
	return byte >= 48 and byte <= 57 -- 0-9
end

-- Check if character is whitespace (but not newline)
function Tokens.isWhitespace(char: string): boolean
	return char == " " or char == "\t" or char == "\f" or char == "\v"
end

return Tokens
