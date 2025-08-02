--!strict
-- PyLua Parser - AST generation from tokens
-- Phase 2 - Will implement recursive descent parser

local Parser = {}

-- Import types when available
-- local lexer = require('./lexer')
-- type Token = lexer.Token

-- AST node placeholder (will be defined in ast/nodes.luau)
export type ASTNode = {
    type: string,
    lineno: number,
    col_offset: number,
}

-- Parse tokens into AST
function Parser.parse(tokens: {any}): ASTNode
    -- TODO: Implement parser in Phase 2
    error("Parser not implemented yet - Phase 2", 2)
end

return Parser
