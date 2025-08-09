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
local parsePostfix: (ParserState, Expr) -> Expr

-- Small lookahead utility
local function lookahead(state: ParserState, offset: number): Token?
    local idx = state.pos + offset
    if idx >= 1 and idx <= #state.tokens then
        return state.tokens[idx]
    end
    return nil
end

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
        local node: Expr = {
            type = "Name",
            id = current.value,
            ctx = "Load",
            lineno = current.line,
            col_offset = current.column,
        } :: any
        return parsePostfix(state, node)
    end

    -- List literal: [a, b, c]
    if current.type == "LSQB" then
        advance(state) -- consume '['
        local elts: {Expr} = {}
        while state.current and not match(state, "RSQB") do
            if match(state, "STAR") then
                advance(state)
                local starredValue = parseExpression(state)
                table.insert(elts, { type = "Starred", value = starredValue, ctx = "Load", lineno = starredValue.lineno, col_offset = starredValue.col_offset } :: any)
            else
                local elt = parseExpression(state)
                table.insert(elts, elt)
            end
            if match(state, "COMMA") then
                advance(state)
            else
                break
            end
        end
        consume(state, "RSQB", "Expected ']' to close list literal")
        local listNode: Expr = {
            type = "List",
            elts = elts,
            ctx = "Load",
            lineno = current.line,
            col_offset = current.column,
        } :: any
        return parsePostfix(state, listNode)
    end

    -- Tuple literal or parenthesized (handled later after LPAR)
    -- Dict / Set literal starting with '{'
    if current.type == "LBRACE" then
        advance(state) -- consume '{'
        local keys: {Expr?} = {}
        local values: {Expr} = {}
        local elts: {Expr} = {}
        local isDict = false
        local hasElements = false
        while state.current and not match(state, "RBRACE") do
            hasElements = true
            -- Look ahead for ':' to decide dict vs set
            local firstExpr: Expr
            if match(state, "DOUBLESTAR") then
                -- dict unpack **expr -> represented by DictUnpack node in keys array
                advance(state)
                local unpackExpr = parseExpression(state)
                local unpackNode: Expr = { type = "DictUnpack", value = unpackExpr, lineno = unpackExpr.lineno, col_offset = unpackExpr.col_offset } :: any
                table.insert(keys, unpackNode)
                table.insert(values, unpackExpr)
                isDict = true
            else
                if match(state, "STAR") then
                    -- set starred element *a
                    advance(state)
                    local starredInner = parseExpression(state)
                    firstExpr = { type = "Starred", value = starredInner, ctx = "Load", lineno = starredInner.lineno, col_offset = starredInner.col_offset } :: any
                else
                    firstExpr = parseExpression(state)
                end
                if match(state, "COLON") then
                    isDict = true
                    advance(state) -- consume ':'
                    local valueExpr = parseExpression(state)
                    table.insert(keys, firstExpr)
                    table.insert(values, valueExpr)
                else
                    if isDict then
                        error("Mixed set and dict elements in literal")
                    end
                    table.insert(elts, firstExpr)
                end
            end
            if match(state, "COMMA") then
                advance(state)
            else
                break
            end
        end
        consume(state, "RBRACE", "Expected '}' to close literal")
        local node: Expr
        if not hasElements then
            -- Empty dict: {}
            node = {
                type = "Dict",
                keys = {},
                values = {},
                lineno = current.line,
                col_offset = current.column,
            } :: any
        elseif isDict then
            node = {
                type = "Dict",
                keys = keys,
                values = values,
                lineno = current.line,
                col_offset = current.column,
            } :: any
        else
            node = {
                type = "Set",
                elts = elts,
                lineno = current.line,
                col_offset = current.column,
            } :: any
        end
        return parsePostfix(state, node)
    end
    
    -- Parenthesized expressions / tuple literal
    if current.type == "LPAR" then
        advance(state) -- consume '('
        if match(state, "RPAR") then
            advance(state)
            -- Empty tuple
            local tupleNode: Expr = {
                type = "Tuple",
                elts = {},
                ctx = "Load",
                lineno = current.line,
                col_offset = current.column,
            } :: any
            return parsePostfix(state, tupleNode)
        end
        local elements: {Expr} = {}
        local first: Expr
        if match(state, "STAR") then
            advance(state)
            local starredInner = parseExpression(state)
            first = { type = "Starred", value = starredInner, ctx = "Load", lineno = starredInner.lineno, col_offset = starredInner.col_offset } :: any
        else
            first = parseExpression(state)
        end
        if match(state, "COMMA") then
            -- Tuple with at least two elements
            table.insert(elements, first)
            while match(state, "COMMA") do
                advance(state)
                if match(state, "RPAR") then break end
                local nextExpr: Expr
                if match(state, "STAR") then
                    advance(state)
                    local starredInner = parseExpression(state)
                    nextExpr = { type = "Starred", value = starredInner, ctx = "Load", lineno = starredInner.lineno, col_offset = starredInner.col_offset } :: any
                else
                    nextExpr = parseExpression(state)
                end
                table.insert(elements, nextExpr)
            end
            consume(state, "RPAR", "Expected ')' to close tuple")
            local tupleNode: Expr = {
                type = "Tuple",
                elts = elements,
                ctx = "Load",
                lineno = first.lineno,
                col_offset = first.col_offset,
            } :: any
            return parsePostfix(state, tupleNode)
        else
            -- Single element or grouped expression
            consume(state, "RPAR", "Expected ')' after expression")
            return parsePostfix(state, first)
        end
    end
    
    error("Unexpected token in expression: " .. current.type)
end

-- Parse function call arguments and keywords
local function parseCallArgs(state: ParserState): ({Expr}, {any})
    local args: {Expr} = {}
    local keywords: {any} = {}
    while state.current and not match(state, "RPAR") do
        -- keyword if NAME and next token is '='
        if match(state, "NAME") and state.pos < #state.tokens and state.tokens[state.pos + 1].type == "EQUAL" then
            local nameTok = state.current :: Token
            advance(state) -- name
            advance(state) -- '='
            local valueExpr = parseExpression(state)
            table.insert(keywords, {
                arg = nameTok.value,
                value = valueExpr,
                lineno = nameTok.line,
                col_offset = nameTok.column,
            })
        elseif match(state, "STAR") then
            advance(state)
            local starredValue = parseExpression(state)
            table.insert(args, { type = "Starred", value = starredValue, ctx = "Load", lineno = starredValue.lineno, col_offset = starredValue.col_offset } :: any)
        elseif match(state, "DOUBLESTAR") then
            advance(state)
            local kwValue = parseExpression(state)
            table.insert(keywords, { arg = nil, value = kwValue, lineno = kwValue.lineno, col_offset = kwValue.col_offset })
        else
            local expr = parseExpression(state)
            table.insert(args, expr)
        end
        if match(state, "COMMA") then
            advance(state)
            if match(state, "RPAR") then break end
        else
            break
        end
    end
    return args, keywords
end

-- Parse attribute / subscript / call chains (postfix operations)
parsePostfix = function(state: ParserState, expr: Expr): Expr
    while true do
        local current = peek(state)
        if not current then break end
        if current.type == "DOT" then
            advance(state)
            local nameTok = consume(state, "NAME", "Expected attribute name after '.'")
            expr = {
                type = "Attribute",
                value = expr,
                attr = nameTok.value,
                ctx = "Load",
                lineno = nameTok.line,
                col_offset = nameTok.column,
            } :: any
        elseif current.type == "LSQB" then
            advance(state) -- consume '['
            local indexExpr = parseExpression(state)
            consume(state, "RSQB", "Expected ']' after subscript expression")
            expr = {
                type = "Subscript",
                value = expr,
                slice = indexExpr,
                ctx = "Load",
                lineno = indexExpr.lineno,
                col_offset = indexExpr.col_offset,
            } :: any
        elseif current.type == "LPAR" then
            advance(state) -- consume '('
            local args, keywords = parseCallArgs(state)
            consume(state, "RPAR", "Expected ')' to close call arguments")
            expr = {
                type = "Call",
                func = expr,
                args = args,
                keywords = keywords,
                lineno = expr.lineno,
                col_offset = expr.col_offset,
            } :: any
        else
            break
        end
    end
    return expr
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
local function getCompareOp(tokenType: TokenType, nextTok: Token?): nodes.CmpOp?
    if tokenType == "EQEQUAL" then return "Eq" end
    if tokenType == "NOTEQUAL" then return "NotEq" end
    if tokenType == "LESS" then return "Lt" end
    if tokenType == "LESSEQUAL" then return "LtE" end
    if tokenType == "GREATER" then return "Gt" end
    if tokenType == "GREATEREQUAL" then return "GtE" end
    if tokenType == "IS" then
        if nextTok and nextTok.type == "NOT" then
            return "IsNot"
        end
        return "Is"
    end
    if tokenType == "IN" then return "In" end
    if tokenType == "NOT" and nextTok and nextTok.type == "IN" then
        return "NotIn"
    end
    return nil
end

-- Parse binary expressions with precedence climbing
local function parseBinaryExpression(state: ParserState, minPrec: number): Expr
    local left = parseUnary(state)

    local function foldComparison(base: Expr, firstTok: Token, firstOp: nodes.CmpOp): Expr
        local ops = {firstOp}
        local comparators: {Expr} = {}
        local rhs = parseUnary(state)
        table.insert(comparators, rhs)
        while true do
            local t = peek(state)
            if not t then break end
            local nextTok = lookahead(state, 1)
            local op2 = getCompareOp(t.type, nextTok)
            if not op2 then break end
            if t.type == "IS" and nextTok and nextTok.type == "NOT" then
                advance(state); advance(state)
            elseif t.type == "NOT" and nextTok and nextTok.type == "IN" then
                advance(state); advance(state)
            else
                advance(state)
            end
            local r2 = parseUnary(state)
            table.insert(ops, op2)
            table.insert(comparators, r2)
        end
        return { type = "Compare", left = base, ops = ops, comparators = comparators, lineno = firstTok.line, col_offset = firstTok.column } :: any
    end

    while true do
        local current = peek(state)
        if not current then break end
        local prec = PRECEDENCE[current.type]
        if not prec or prec < minPrec then break end

        if current.type == "AND" or current.type == "OR" then
            local boolType = (current.type == "AND") and "And" or "Or"
            local values = {left}
            repeat
                advance(state)
                local rhs = parseBinaryExpression(state, PRECEDENCE[current.type] + 1)
                table.insert(values, rhs)
                current = peek(state)
            until not current or current.type ~= ((boolType == "And") and "AND" or "OR")
            left = { type = "BoolOp", op = boolType, values = values, lineno = values[1].lineno, col_offset = values[1].col_offset } :: any
        else
            local nextTok = lookahead(state, 1)
            local cmpOp: nodes.CmpOp? = getCompareOp(current.type, nextTok)
            if cmpOp then
                -- consume operator token(s)
                    local opToken = current
                    if current.type == "IS" and nextTok and nextTok.type == "NOT" then
                        advance(state); advance(state)
                    elseif current.type == "NOT" and nextTok and nextTok.type == "IN" then
                        advance(state); advance(state)
                    else
                        advance(state)
                    end
                    left = foldComparison(left, opToken, cmpOp :: nodes.CmpOp)
            else
                local op = getBinaryOp(current.type)
                if not op then break end
                advance(state)
                local right = parseBinaryExpression(state, prec + 1)
                left = { type = "BinOp", left = left, op = op, right = right, lineno = current.line, col_offset = current.column } :: any
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

-- Parse a potential assignment target without consuming binary operators
local function parseTargetOnly(state: ParserState): Expr?
    local tok = peek(state)
    if not tok then return nil end
    -- Only attempt if it could start a simple assignment target (Name, possibly with postfix)
    if tok.type == "NAME" then
        return parsePrimary(state)
    end
    return nil
end

-- Parse assignment target (for Store context)
local function parseAssignmentTarget(expr: Expr): Expr
    if expr.type == "Name" or expr.type == "Attribute" or expr.type == "Subscript" then
        local e = expr :: any
        e.ctx = "Store"
        return e
    end
    return expr -- fallback
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
    
    -- Attempt target-only parse for assignment / augassign
    local savePos = state.pos
    local saveCurrent = state.current
    local targetCandidate = parseTargetOnly(state)
    if targetCandidate then
        local afterTarget = peek(state)
        if afterTarget and afterTarget.type == "EQUAL" then
            advance(state) -- '='
            local value = parseExpression(state)
            local target = parseAssignmentTarget(targetCandidate)
            return { type = "Assign", targets = {target}, value = value, lineno = target.lineno, col_offset = target.col_offset } :: any
        elseif afterTarget then
            local opTok = afterTarget
            local nextTok = lookahead(state, 1)
            local opMap: {[string]: nodes.BinOpType} = { PLUS = "Add", MINUS = "Sub", STAR = "Mult", SLASH = "Div", DOUBLESLASH = "FloorDiv", PERCENT = "Mod", DOUBLESTAR = "Pow", LEFTSHIFT = "LShift", RIGHTSHIFT = "RShift", AMPER = "BitAnd", CIRCUMFLEX = "BitXor", VBAR = "BitOr", AT = "MatMult" }
            if nextTok and nextTok.type == "EQUAL" and opMap[opTok.type] then
                advance(state) -- operator
                advance(state) -- '='
                local value = parseExpression(state)
                local target = parseAssignmentTarget(targetCandidate)
                return { type = "AugAssign", target = target, op = opMap[opTok.type], value = value, lineno = target.lineno, col_offset = target.col_offset } :: any
            end
        end
        -- Not an assignment, restore state and parse as expression
        state.pos = savePos
        state.current = saveCurrent
    else
        -- No viable assignment target start, restore position (parseTargetOnly consumed nothing)
        state.pos = savePos
        state.current = saveCurrent
    end
    local expr = parseExpression(state)
    return { type = "Expr", value = expr, lineno = expr.lineno, col_offset = expr.col_offset } :: any
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
