local errors = {}

export type Location = { line: number, column: number }

local function fmtLocation(loc: Location?): string
	if not loc then
		return "<unknown>"
	end
	return string.format("line %d, column %d", loc.line, loc.column)
end

function errors.expected(expected: string, got: string?, loc: Location?)
	return string.format("ParseError: expected %s but got %s at %s", expected, got or "<eof>", fmtLocation(loc))
end

-- Simple raise helper (throws Lua error)
function errors.raise(msg: string, loc: Location?)
	if loc then
		error(string.format("%s at %s", msg, fmtLocation(loc)), 0)
	else
		error(msg, 0)
	end
end

function errors.synchronize(tokens: { any }, startPos: number): number
	local pos = math.max(startPos, 1)
	while pos <= #tokens do
		local token = tokens[pos]
		local tokenType = token and token.type
		if tokenType == "NEWLINE" or tokenType == "DEDENT" or tokenType == "ENDMARKER" then
			return pos
		end
		pos += 1
	end
	return #tokens
end

return errors
