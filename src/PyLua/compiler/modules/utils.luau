-- PyLua Compiler Utilities
-- Token parsing and validation utilities

local tokenizer = require('../tokenizer')

local Utils = {}

-- Parse a number literal
function Utils.parseNumber(token: string): number
    local num = tonumber(token)
    if num then
        return num
    end
    error("Invalid number: " .. tostring(token))
end

-- Parse a string literal
function Utils.parseString(token: string): string
    -- Remove quotes and return the string content
    if (token:sub(1, 1) == "\"" and token:sub(-1, -1) == "\"") or
       (token:sub(1, 1) == "'" and token:sub(-1, -1) == "'") then
        return token:sub(2, -2)
    end
    error("Invalid string: " .. tostring(token))
end

-- Check if a token is a number
function Utils.isNumber(token: string): boolean
    return tonumber(token) ~= nil
end

-- Check if a token is a string literal
function Utils.isString(token: string): boolean
    return (token:sub(1, 1) == "\"" and token:sub(-1, -1) == "\"") or
           (token:sub(1, 1) == "'" and token:sub(-1, -1) == "'")
end

-- Check if a token is an identifier
function Utils.isIdentifier(token: string): boolean
    return token:match("^[a-zA-Z_][a-zA-Z0-9_]*$") ~= nil
end

-- Check if a token is a binary operator
function Utils.isBinaryOperator(token: string): boolean
    return token == "+" or token == "-" or token == "*" or token == "/" or 
           token == "%" or token == "==" or token == "!=" or token == "<" or
           token == ">" or token == "<=" or token == ">="
end

-- Get operator precedence (higher number = higher precedence)
function Utils.getOperatorPrecedence(op: string): number
    if op == "==" or op == "!=" or op == "<" or op == ">" or op == "<=" or op == ">=" then
        return 1
    elseif op == "+" or op == "-" then
        return 2
    elseif op == "*" or op == "/" or op == "%" then
        return 3
    end
    return 0
end

-- Check if a line has unclosed delimiters (for multi-line statements)
function Utils.hasUnclosedDelimiters(tokens: {string}): boolean
    local openParens = 0
    local openBrackets = 0
    local openBraces = 0
    
    for _, token in ipairs(tokens) do
        if token == "(" then
            openParens = openParens + 1
        elseif token == ")" then
            openParens = openParens - 1
        elseif token == "[" then
            openBrackets = openBrackets + 1
        elseif token == "]" then
            openBrackets = openBrackets - 1
        elseif token == "{" then
            openBraces = openBraces + 1
        elseif token == "}" then
            openBraces = openBraces - 1
        end
    end
    
    return openParens > 0 or openBrackets > 0 or openBraces > 0
end

-- Collect multi-line statement tokens (for object literals spanning multiple lines)
function Utils.collectMultiLineStatement(lines: {string}, startLine: number): ({string}, number)
    local allTokens: {string} = {}
    local currentLine = startLine
    
    while currentLine <= #lines do
        local line = lines[currentLine]
        local trimmed = line:match("^%s*(.-)%s*$") or ""
        
        if trimmed ~= "" and not trimmed:match("^#") then
            local lineTokens = tokenizer.tokenize(trimmed)
            for _, token in ipairs(lineTokens) do
                table.insert(allTokens, token)
            end
            
            -- Check if statement is now complete
            if not Utils.hasUnclosedDelimiters(allTokens) then
                break
            end
        end
        
        currentLine = currentLine + 1
    end
    
    return allTokens, currentLine
end

return Utils
