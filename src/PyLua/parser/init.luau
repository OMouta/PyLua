local tokens = require("./tokens")
local nodes = require("./ast/nodes")
local errors = require("@self/errors")
local expressions = require("@self/expressions")
local statements = require("@self/statements")

export type Token = tokens.Token
export type Module = nodes.Module
export type Expr = nodes.Expr
export type Stmt = nodes.Stmt

local Parser = {}

-- Parser state object (OO-ish wrapper giving methods for modules)
local State = {}
State.__index = State

export type ParserState = {
	tokens: { Token },
	pos: number,
	current: Token?,
	advance: (self: any) -> (),
	consume: (self: any, tokenType: string, message: string?) -> Token,
	raise: (self: any, msg: string) -> (),
	lookahead: (self: any, offset: number) -> Token?,
}

function State.new(tokenList: { Token })
	local self: ParserState = setmetatable({
		tokens = tokenList,
		pos = 1,
		current = tokenList[1],
	}, State) :: any
	return self
end

function State:advance()
	if self.pos < #self.tokens then
		self.pos += 1
		self.current = self.tokens[self.pos]
	else
		self.current = nil
	end
end

function State:lookahead(offset: number): Token?
	local idx = self.pos :: number + offset
	if idx >= 1 and idx <= #self.tokens then
		return self.tokens[idx]
	end
	return nil
end

function State:consume(tokenType: string, message: string?): Token
	local cur = self.current
	if not cur then
		local lastToken = self.tokens[#self.tokens]
		errors.raise(message or ("Expected " .. tokenType .. " but reached end of input"), lastToken)
	end
	if cur.type ~= tokenType then
		errors.raise(message or ("Expected " .. tokenType .. " but got " .. cur.type), cur)
	end
	self:advance()
	return cur :: any
end

function State:raise(msg: string)
	errors.raise(msg, self.current)
end

local function skipLayout(state: ParserState)
	while
		state.current
		and (
			state.current.type == "NEWLINE"
			or state.current.type == "INDENT"
			or state.current.type == "DEDENT"
			or state.current.type == "COMMENT"
		)
	do
		state:advance()
	end
end

-- Module-level parse entry
function Parser.parse(tokenList: { Token }): Module
	local state = State.new(tokenList)
	local body: { Stmt } = {}
	while state.current and state.current.type ~= "ENDMARKER" do
		skipLayout(state)
		if not state.current or state.current.type == "ENDMARKER" then
			break
		end
		local stmt = statements.parse(state)
		table.insert(body, stmt)
		while state.current and state.current.type == "NEWLINE" do
			state:advance()
		end
	end
	return { type = "Module", body = body, type_ignores = nil, lineno = 1, col_offset = 1 } :: any
end

function Parser.parseExpression(tokenList: { Token }): Expr
	local state = State.new(tokenList)
	return expressions.parse(state)
end

return Parser
