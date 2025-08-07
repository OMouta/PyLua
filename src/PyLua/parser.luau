--!strict
-- PyLua Parser - AST generation from tokens
-- Phase 2.1 - Expression Parser Implementation

local Parser = {}

-- Import dependencies
local tokens = require('./tokens')
local nodes = require('./ast/nodes')

type Token = tokens.Token
type TokenType = tokens.TokenType
type ASTNode = nodes.ASTNode
type Expr = nodes.Expr
type Stmt = nodes.Stmt
type Module = nodes.Module

-- Parser state
type ParserState = {
    tokens: {Token},
    pos: number,
    current: Token?,
}

-- ========== PARSER STATE MANAGEMENT ==========

-- Create new parser state
local function newParserState(tokenList: {Token}): ParserState
    local state: ParserState = {
        tokens = tokenList,
        pos = 1,
        current = nil,
    }
    
    -- Set initial current token
    if #tokenList > 0 then
        state.current = tokenList[1] :: Token
    end
    
    return state
end

-- Get current token
local function peek(state: ParserState): Token?
    return state.current
end

-- Advance to next token
local function advance(state: ParserState): Token?
    if state.pos < #state.tokens then
        state.pos = state.pos + 1
        state.current = state.tokens[state.pos]
    else
        state.current = nil
    end
    return state.current
end

-- Check if current token matches type
local function match(state: ParserState, tokenType: TokenType): boolean
    local current = peek(state)
    return current ~= nil and current.type == tokenType
end

-- Consume token if it matches, otherwise error
local function consume(state: ParserState, tokenType: TokenType, message: string?): Token
    local current = peek(state)
    if not current then
        error(message or ("Expected " .. tokenType .. " but reached end of input"))
    end
    
    if current.type ~= tokenType then
        error(message or ("Expected " .. tokenType .. " but got " .. current.type))
    end
    
    advance(state)
    return current
end

-- ========== PYTHON OPERATOR PRECEDENCE ==========
-- Following Python's operator precedence (lowest to highest)

-- Precedence levels (lower number = lower precedence)
local PRECEDENCE = {
    -- Logical OR
    ["OR"] = 1,
    
    -- Logical AND  
    ["AND"] = 2,
    
    -- Logical NOT (unary)
    ["NOT"] = 3,
    
    -- Comparisons, membership, identity
    ["IN"] = 4, ["NOT_IN"] = 4, ["IS"] = 4, ["IS_NOT"] = 4,
    ["LESS"] = 4, ["LESSEQUAL"] = 4, ["GREATER"] = 4, ["GREATEREQUAL"] = 4,
    ["EQEQUAL"] = 4, ["NOTEQUAL"] = 4,
    
    -- Bitwise OR
    ["VBAR"] = 5,
    
    -- Bitwise XOR
    ["CIRCUMFLEX"] = 6,
    
    -- Bitwise AND
    ["AMPER"] = 7,
    
    -- Shifts
    ["LEFTSHIFT"] = 8, ["RIGHTSHIFT"] = 8,
    
    -- Addition and subtraction
    ["PLUS"] = 9, ["MINUS"] = 9,
    
    -- Multiplication, division, remainder
    ["STAR"] = 10, ["SLASH"] = 10, ["DOUBLESLASH"] = 10, ["PERCENT"] = 10,
    
    -- Unary +, -, ~ (handled specially)
    ["UNARY"] = 11,
    
    -- Exponentiation (right-associative)
    ["DOUBLESTAR"] = 12,
}

-- ========== EXPRESSION PARSING ==========

-- Forward declarations
local parseExpression: (ParserState) -> Expr
local parsePrimary: (ParserState) -> Expr

-- Parse a primary expression (literals, names, parentheses)
parsePrimary = function(state: ParserState): Expr
    local current = peek(state)
    if not current then
        error("Unexpected end of input in expression")
    end
    
    -- Numbers
    if current.type == "NUMBER" then
        advance(state)
        local value = current.value
        
        -- Parse number value
        local numValue: any
        if string.find(value, "^0b") then
            -- Binary
            numValue = tonumber(string.sub(value, 3), 2)
        elseif string.find(value, "^0o") then
            -- Octal
            numValue = tonumber(string.sub(value, 3), 8)
        elseif string.find(value, "^0x") then
            -- Hexadecimal
            numValue = tonumber(string.sub(value, 3), 16)
        elseif string.find(value, "%.") or string.find(value, "[eE]") then
            -- Float
            numValue = tonumber(value)
        else
            -- Integer
            numValue = tonumber(value)
        end
        
        return {
            type = "Constant",
            value = numValue,
            kind = nil,
            lineno = current.line,
            col_offset = current.column,
        } :: any
    end
    
    -- Strings
    if current.type == "STRING" then
        advance(state)
        local value = current.value
        
        -- Parse string literal (simplified for now)
        local stringValue = string.sub(value, 2, -2) -- Remove quotes
        
        return {
            type = "Constant",
            value = stringValue,
            kind = nil,
            lineno = current.line,
            col_offset = current.column,
        } :: any
    end
    
    -- Boolean literals and None
    if current.type == "TRUE" then
        advance(state)
        return {
            type = "Constant",
            value = true,
            kind = nil,
            lineno = current.line,
            col_offset = current.column,
        } :: any
    end
    
    if current.type == "FALSE" then
        advance(state)
        return {
            type = "Constant",
            value = false,
            kind = nil,
            lineno = current.line,
            col_offset = current.column,
        } :: any
    end
    
    if current.type == "NONE" then
        advance(state)
        return {
            type = "Constant",
            value = nil,
            kind = nil,
            lineno = current.line,
            col_offset = current.column,
        } :: any
    end
    
    -- Names (variables)
    if current.type == "NAME" then
        advance(state)
        local name = {
            type = "Name",
            id = current.value,
            ctx = "Load",
            lineno = current.line,
            col_offset = current.column,
        } :: any
        
        -- Check for function call
        if match(state, "LPAR") then
            advance(state) -- consume '('
            
            -- Parse arguments (simplified - just expressions for now)
            local args = {}
            
            while not match(state, "RPAR") and state.current do
                local arg = parseExpression(state)
                table.insert(args, arg)
                
                if match(state, "COMMA") then
                    advance(state)
                end
            end
            
            consume(state, "RPAR", "Expected ')' after function arguments")
            
            return {
                type = "Call",
                func = name,
                args = args,
                keywords = {},
                lineno = current.line,
                col_offset = current.column,
            } :: any
        end
        
        return name
    end
    
    -- Parenthesized expressions
    if current.type == "LPAR" then
        advance(state) -- consume '('
        local expr = parseExpression(state)
        consume(state, "RPAR", "Expected ')' after expression")
        return expr
    end
    
    error("Unexpected token in expression: " .. current.type)
end

-- Parse unary expressions (-, +, ~, not)
local function parseUnary(state: ParserState): Expr
    local current = peek(state)
    if not current then
        return parsePrimary(state)
    end
    
    -- Unary operators
    if current.type == "MINUS" then
        advance(state)
        local operand = parseUnary(state)
        return {
            type = "UnaryOp",
            op = "USub",
            operand = operand,
            lineno = current.line,
            col_offset = current.column,
        } :: any
    end
    
    if current.type == "PLUS" then
        advance(state)
        local operand = parseUnary(state)
        return {
            type = "UnaryOp",
            op = "UAdd",
            operand = operand,
            lineno = current.line,
            col_offset = current.column,
        } :: any
    end
    
    if current.type == "TILDE" then
        advance(state)
        local operand = parseUnary(state)
        return {
            type = "UnaryOp",
            op = "Invert",
            operand = operand,
            lineno = current.line,
            col_offset = current.column,
        } :: any
    end
    
    if current.type == "NOT" then
        advance(state)
        local operand = parseUnary(state)
        return {
            type = "UnaryOp",
            op = "Not",
            operand = operand,
            lineno = current.line,
            col_offset = current.column,
        } :: any
    end
    
    return parsePrimary(state)
end

-- Get binary operator from token
local function getBinaryOp(tokenType: TokenType): nodes.BinOpType?
    if tokenType == "PLUS" then return "Add" end
    if tokenType == "MINUS" then return "Sub" end
    if tokenType == "STAR" then return "Mult" end
    if tokenType == "SLASH" then return "Div" end
    if tokenType == "DOUBLESLASH" then return "FloorDiv" end
    if tokenType == "PERCENT" then return "Mod" end
    if tokenType == "DOUBLESTAR" then return "Pow" end
    if tokenType == "LEFTSHIFT" then return "LShift" end
    if tokenType == "RIGHTSHIFT" then return "RShift" end
    if tokenType == "VBAR" then return "BitOr" end
    if tokenType == "CIRCUMFLEX" then return "BitXor" end
    if tokenType == "AMPER" then return "BitAnd" end
    if tokenType == "AT" then return "MatMult" end
    return nil
end

-- Get comparison operator from token
local function getCompareOp(tokenType: TokenType): nodes.CmpOp?
    if tokenType == "EQEQUAL" then return "Eq" end
    if tokenType == "NOTEQUAL" then return "NotEq" end
    if tokenType == "LESS" then return "Lt" end
    if tokenType == "LESSEQUAL" then return "LtE" end
    if tokenType == "GREATER" then return "Gt" end
    if tokenType == "GREATEREQUAL" then return "GtE" end
    if tokenType == "IS" then return "Is" end
    if tokenType == "IN" then return "In" end
    return nil
end

-- Parse binary expressions with precedence climbing
local function parseBinaryExpression(state: ParserState, minPrec: number): Expr
    local left = parseUnary(state)
    
    while true do
        local current = peek(state)
        if not current then
            break
        end
        
        local prec = PRECEDENCE[current.type]
        if not prec or prec < minPrec then
            break
        end
        
        local op = getBinaryOp(current.type)
        if op then
            -- Binary arithmetic operator
            advance(state)
            local right = parseBinaryExpression(state, prec + 1)
            left = {
                type = "BinOp",
                left = left,
                op = op,
                right = right,
                lineno = current.line,
                col_offset = current.column,
            } :: any
        else
            -- Could be comparison or other operators
            local cmpOp = getCompareOp(current.type)
            if cmpOp then
                advance(state)
                local right = parseBinaryExpression(state, prec + 1)
                left = {
                    type = "Compare",
                    left = left,
                    ops = {cmpOp},
                    comparators = {right},
                    lineno = current.line,
                    col_offset = current.column,
                } :: any
            else
                break
            end
        end
    end
    
    return left
end

-- Main expression parser entry point
parseExpression = function(state: ParserState): Expr
    return parseBinaryExpression(state, 1)
end

-- ========== STATEMENT PARSING ==========

-- Forward declarations
local parseStatement: (ParserState) -> Stmt
local parseSimpleStatement: (ParserState) -> Stmt
local parseCompoundStatement: (ParserState) -> Stmt

-- Parse assignment target (for Store context)
local function parseAssignmentTarget(expr: Expr): Expr
    -- Convert Load context to Store context for assignment
    if expr.type == "Name" then
        local nameExpr = expr :: any
        nameExpr.ctx = "Store"
        return nameExpr
    end
    
    -- TODO: Handle other assignment targets (subscripts, attributes, etc.)
    return expr
end

-- Parse a simple statement (assignment, expression statement)
parseSimpleStatement = function(state: ParserState): Stmt
    local current = peek(state)
    if not current then
        error("Unexpected end of input in statement")
    end
    
    -- Return statement
    if current.type == "RETURN" then
        advance(state) -- consume 'return'
        local value: Expr? = nil
        
        -- Check if there's a return value
        if state.current and state.current.type ~= "NEWLINE" and 
           state.current.type ~= "ENDMARKER" and state.current.type ~= "DEDENT" then
            value = parseExpression(state)
        end
        
        return {
            type = "Return",
            value = value,
            lineno = current.line,
            col_offset = current.column,
        } :: any
    end
    
    -- Try to parse as an expression first
    local expr = parseExpression(state)
    
    -- Check if this is an assignment
    if match(state, "EQUAL") then
        advance(state) -- consume '='
        local value = parseExpression(state)
        
        -- Convert expression to assignment target
        local target = parseAssignmentTarget(expr)
        
        return {
            type = "Assign",
            targets = {target},
            value = value,
            lineno = expr.lineno,
            col_offset = expr.col_offset,
        } :: any
    end
    
    -- Otherwise, it's an expression statement
    return {
        type = "Expr",
        value = expr,
        lineno = expr.lineno,
        col_offset = expr.col_offset,
    } :: any
end

-- Parse compound statement (if, while, for, def)
parseCompoundStatement = function(state: ParserState): Stmt
    local current = peek(state)
    if not current then
        error("Unexpected end of input in compound statement")
    end
    
    -- If statement: if condition: ...
    if current.type == "IF" then
        advance(state) -- consume 'if'
        local test = parseExpression(state)
        consume(state, "COLON", "Expected ':' after if condition")
        
        -- Skip newline and indent after colon
        if match(state, "NEWLINE") then
            advance(state)
        end
        if match(state, "INDENT") then
            advance(state)
        end
        
        -- Parse if body
        local body: {Stmt} = {}
        
        -- Parse statements until we see DEDENT, elif, else, or end
        while state.current and state.current.type ~= "ENDMARKER" and 
              state.current.type ~= "DEDENT" and state.current.type ~= "ELIF" and 
              state.current.type ~= "ELSE" do
            local stmt = parseStatement(state)
            table.insert(body, stmt)
            
            -- Skip newlines between statements
            while match(state, "NEWLINE") do
                advance(state)
            end
        end
        
        -- Consume DEDENT if present
        if match(state, "DEDENT") then
            advance(state)
        end
        
        -- Handle elif/else (simplified for now)
        local orelse: {Stmt} = {}
        
        return {
            type = "If",
            test = test,
            body = body,
            orelse = orelse,
            lineno = current.line,
            col_offset = current.column,
        } :: any
    end
    
    -- While statement: while condition: ...
    if current.type == "WHILE" then
        advance(state) -- consume 'while'
        local test = parseExpression(state)
        consume(state, "COLON", "Expected ':' after while condition")
        
        -- Skip newline and indent after colon
        if match(state, "NEWLINE") then
            advance(state)
        end
        if match(state, "INDENT") then
            advance(state)
        end
        
        -- Parse while body
        local body: {Stmt} = {}
        while state.current and state.current.type ~= "ENDMARKER" and state.current.type ~= "DEDENT" do
            local stmt = parseStatement(state)
            table.insert(body, stmt)
            
            while match(state, "NEWLINE") do
                advance(state)
            end
        end
        
        if match(state, "DEDENT") then
            advance(state)
        end
        
        local orelse: {Stmt} = {} -- while-else clause
        
        return {
            type = "While",
            test = test,
            body = body,
            orelse = orelse,
            lineno = current.line,
            col_offset = current.column,
        } :: any
    end
    
    -- For statement: for target in iter: ...
    if current.type == "FOR" then
        advance(state) -- consume 'for'
        -- Parse target as primary expression only (no operators allowed)
        local target = parsePrimary(state)
        consume(state, "IN", "Expected 'in' after for target")
        local iter = parseExpression(state)
        consume(state, "COLON", "Expected ':' after for clause")
        
        -- Skip newline and indent after colon
        if match(state, "NEWLINE") then
            advance(state)
        end
        if match(state, "INDENT") then
            advance(state)
        end
        
        -- Parse for body
        local body: {Stmt} = {}
        while state.current and state.current.type ~= "ENDMARKER" and state.current.type ~= "DEDENT" do
            local stmt = parseStatement(state)
            table.insert(body, stmt)
            
            while match(state, "NEWLINE") do
                advance(state)
            end
        end
        
        if match(state, "DEDENT") then
            advance(state)
        end
        
        local orelse: {Stmt} = {} -- for-else clause
        
        -- Convert target to Store context
        target = parseAssignmentTarget(target)
        
        return {
            type = "For",
            target = target,
            iter = iter,
            body = body,
            orelse = orelse,
            lineno = current.line,
            col_offset = current.column,
        } :: any
    end
    
    -- Function definition: def name(args): ...
    if current.type == "DEF" then
        advance(state) -- consume 'def'
        local nameToken = consume(state, "NAME", "Expected function name after 'def'")
        local name = nameToken.value
        
        consume(state, "LPAR", "Expected '(' after function name")
        
        -- Parse arguments (simplified - just empty for now)
        local args = {
            posonlyargs = {},
            args = {},
            vararg = nil,
            kwonlyargs = {},
            kw_defaults = {},
            kwarg = nil,
            defaults = {},
        }
        
        consume(state, "RPAR", "Expected ')' after function arguments")
        consume(state, "COLON", "Expected ':' after function signature")
        
        -- Skip newline and indent after colon
        if match(state, "NEWLINE") then
            advance(state)
        end
        if match(state, "INDENT") then
            advance(state)
        end
        
        -- Parse function body
        local body: {Stmt} = {}
        while state.current and state.current.type ~= "ENDMARKER" and state.current.type ~= "DEDENT" do
            local stmt = parseStatement(state)
            table.insert(body, stmt)
            
            while match(state, "NEWLINE") do
                advance(state)
            end
        end
        
        if match(state, "DEDENT") then
            advance(state)
        end
        
        return {
            type = "FunctionDef",
            name = name,
            args = args,
            body = body,
            decorator_list = {},
            returns = nil,
            lineno = current.line,
            col_offset = current.column,
        } :: any
    end
    
    error("Unknown compound statement: " .. current.type)
end

-- Main statement parser
parseStatement = function(state: ParserState): Stmt
    local current = peek(state)
    if not current then
        error("Unexpected end of input in statement")
    end
    
    -- Check for compound statements
    if current.type == "IF" or current.type == "WHILE" or current.type == "FOR" or current.type == "DEF" then
        return parseCompoundStatement(state)
    end
    
    -- Otherwise, parse as simple statement (including return)
    return parseSimpleStatement(state)
end

-- ========== PUBLIC API ==========

-- Parse tokens into AST
function Parser.parse(tokenList: {Token}): Module
    local state = newParserState(tokenList)
    
    local body: {Stmt} = {}
    
    -- Parse statements until we hit ENDMARKER
    while state.current and state.current.type ~= "ENDMARKER" do
        -- Skip newlines and indentation tokens at the top level
        while match(state, "NEWLINE") or match(state, "INDENT") or match(state, "DEDENT") do
            advance(state)
        end
        
        -- Check if we're at the end after skipping tokens
        if not state.current or state.current.type == "ENDMARKER" then
            break
        end
        
        local stmt = parseStatement(state)
        table.insert(body, stmt)
        
        -- Skip newlines after statements
        while match(state, "NEWLINE") do
            advance(state)
        end
    end
    
    return {
        type = "Module",
        body = body,
        type_ignores = nil,
        lineno = 1,
        col_offset = 1,
    } :: any
end

-- Parse a single expression from tokens
function Parser.parseExpression(tokenList: {Token}): Expr
    local state = newParserState(tokenList)
    return parseExpression(state)
end

return Parser
