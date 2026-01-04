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

-- Placeholder synchronization (future): skip until one of NEWLINE/DEDENT/ENDMARKER
function errors.synchronize(tokens: { any }, startPos: number): number
	-- Not implemented yet; returns original position
	return startPos
end

return errors
