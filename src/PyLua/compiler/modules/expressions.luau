-- PyLua Expression Compilation
-- Handles compilation of expressions including primary expressions, binary operations, and function calls

local types = require('../../core/types')
local opcodes = require('../../vm/opcodes')
local State = require('./state')
local Utils = require('./utils')
local ErrorUtils = require('./error_utils')

type CompilerState = types.CompilerState
type TokenPosition = types.TokenPosition

local Expressions = {}

-- Forward declaration for recursive calls
local compileExpression: (CompilerState, {string}, TokenPosition) -> TokenPosition

-- Compile a primary expression (numbers, strings, identifiers, parenthesized expressions)
function Expressions.compilePrimary(state: CompilerState, tokens: {string}, pos: TokenPosition): TokenPosition
    local token = tokens[pos]
    
    if not token then
        ErrorUtils.throwCompilerError(state, "SyntaxError", "Unexpected end of expression", "Check that all expressions are complete", "While parsing primary expression")
    end
    
    if Utils.isNumber(token) then
        -- Number literal
        local value = Utils.parseNumber(token, state)
        local constIndex = State.addConstant(state, value)
        State.emit(state, opcodes.Opcodes.LOAD_CONST, constIndex)
        return pos + 1
    elseif Utils.isString(token) then
        -- String literal
        local value = Utils.parseString(token, state)
        local constIndex = State.addConstant(state, value)
        State.emit(state, opcodes.Opcodes.LOAD_CONST, constIndex)
        return pos + 1
    elseif token == "True" then
        -- Python True literal
        local constIndex = State.addConstant(state, true)
        State.emit(state, opcodes.Opcodes.LOAD_CONST, constIndex)
        return pos + 1
    elseif token == "False" then
        -- Python False literal
        local constIndex = State.addConstant(state, false)
        State.emit(state, opcodes.Opcodes.LOAD_CONST, constIndex)
        return pos + 1
    elseif token == "None" then
        -- Python None literal
        local constIndex = State.addConstant(state, nil)
        State.emit(state, opcodes.Opcodes.LOAD_CONST, constIndex)
        return pos + 1
    elseif Utils.isIdentifier(token) then
        -- Variable or function name
        local nameIndex = State.addName(state, token)
        State.emit(state, opcodes.Opcodes.LOAD_NAME, nameIndex)
        return pos + 1
    elseif token == "(" then
        -- Parenthesized expression or tuple
        pos = pos + 1
        
        -- Check for empty tuple
        if tokens[pos] == ")" then
            State.emit(state, opcodes.Opcodes.BUILD_TUPLE, 0)
            return pos + 1
        end
        
        -- Parse first expression
        pos = compileExpression(state, tokens, pos)
        
        -- Check if it's a tuple (has comma) or just parenthesized expression
        if tokens[pos] == "," then
            local elementCount = 1
            pos = pos + 1
            
            -- Parse remaining elements
            while tokens[pos] and tokens[pos] ~= ")" do
                pos = compileExpression(state, tokens, pos)
                elementCount = elementCount + 1
                
                if tokens[pos] == "," then
                    pos = pos + 1
                elseif tokens[pos] ~= ")" then
                    ErrorUtils.expectedTokenError(state, "',' or ')'", tokens[pos], state.sourceLines)
                end
            end
            
            if tokens[pos] ~= ")" then
                ErrorUtils.expectedTokenError(state, "')'", tokens[pos], state.sourceLines)
            end
            
            State.emit(state, opcodes.Opcodes.BUILD_TUPLE, elementCount)
            return pos + 1
        else
            -- Just a parenthesized expression
            if tokens[pos] ~= ")" then
                ErrorUtils.expectedTokenError(state, "')'", tokens[pos], state.sourceLines)
            end
            return pos + 1
        end
    elseif token == "[" then
        -- List literal
        pos = pos + 1
        local elementCount = 0
        
        -- Handle empty list
        if tokens[pos] == "]" then
            State.emit(state, opcodes.Opcodes.BUILD_LIST, 0)
            return pos + 1
        end
        
        -- Parse list elements
        while tokens[pos] and tokens[pos] ~= "]" do
            pos = compileExpression(state, tokens, pos)
            elementCount = elementCount + 1
            
            if tokens[pos] == "," then
                pos = pos + 1
            elseif tokens[pos] ~= "]" then
                ErrorUtils.expectedTokenError(state, "',' or ']'", tokens[pos], state.sourceLines)
            end
        end
        
        if tokens[pos] ~= "]" then
            ErrorUtils.expectedTokenError(state, "']'", tokens[pos], state.sourceLines)
        end
        
        State.emit(state, opcodes.Opcodes.BUILD_LIST, elementCount)
        return pos + 1
    elseif token == "{" then
        -- Dictionary or set literal
        pos = pos + 1
        -- Handle empty dict/set
        if tokens[pos] == "}" then
            -- Empty dict (Python convention: {} is dict, set() is empty set)
            State.emit(state, opcodes.Opcodes.BUILD_DICT, 0)
            return pos + 1
        end
        
        -- Parse first element to determine if it's a dict or set
        pos = compileExpression(state, tokens, pos)
        if tokens[pos] == ":" then
            -- Dictionary - we have key:value pairs
            -- The first key was already compiled, now compile its value
            pos = pos + 1  -- skip ':'
            pos = compileExpression(state, tokens, pos)  -- compile value
            local pairCount = 1
            
            -- Parse remaining key-value pairs
            while pos <= #tokens and tokens[pos] == "," do
                pos = pos + 1
                if pos <= #tokens and tokens[pos] == "}" then
                    break  -- trailing comma
                end
                pos = compileExpression(state, tokens, pos)  -- key
                if pos > #tokens or tokens[pos] ~= ":" then
                    ErrorUtils.expectedTokenError(state, "':'", tokens[pos], state.sourceLines)
                end
                pos = pos + 1  -- skip ':'
                pos = compileExpression(state, tokens, pos)  -- value
                pairCount = pairCount + 1
            end
            
            if pos > #tokens or tokens[pos] ~= "}" then
                ErrorUtils.expectedTokenError(state, "'}'", tokens[pos], state.sourceLines)
            end
            
            State.emit(state, opcodes.Opcodes.BUILD_DICT, pairCount)
            return pos + 1
        else
            -- Set - we have individual values
            local elementCount = 1
            -- Parse remaining elements
            while pos <= #tokens and tokens[pos] == "," do
                pos = pos + 1
                if pos <= #tokens and tokens[pos] == "}" then
                    break  -- trailing comma
                end
                
                pos = compileExpression(state, tokens, pos)
                elementCount = elementCount + 1
            end
            
            if pos > #tokens or tokens[pos] ~= "}" then
                ErrorUtils.expectedTokenError(state, "'}'", tokens[pos], state.sourceLines)
            end
            
            State.emit(state, opcodes.Opcodes.BUILD_SET, elementCount)
            return pos + 1
        end
    else
        ErrorUtils.unexpectedTokenError(state, token, state.sourceLines)
        return pos -- This line will never execute but satisfies the type checker
    end
end

-- Compile a function call
function Expressions.compileFunctionCall(state: CompilerState, tokens: {string}, pos: TokenPosition): TokenPosition
    -- The function name should already be loaded onto the stack
    
    if tokens[pos] ~= "(" then
        ErrorUtils.expectedTokenError(state, "'('", tokens[pos], state.sourceLines)
    end
    pos = pos + 1
    
    local argCount = 0
    
    -- Parse arguments
    while tokens[pos] and tokens[pos] ~= ")" do
        if argCount > 0 then
            if tokens[pos] ~= "," then
                ErrorUtils.expectedTokenError(state, "','", tokens[pos], state.sourceLines)
            end
            pos = pos + 1
        end
        
        pos = compileExpression(state, tokens, pos)
        argCount = argCount + 1
    end
    
    if tokens[pos] ~= ")" then
        ErrorUtils.expectedTokenError(state, "')'", tokens[pos], state.sourceLines)
    end
    pos = pos + 1
    
    -- Emit function call instruction
    State.emit(state, opcodes.Opcodes.CALL_FUNCTION, argCount)
    
    return pos
end

-- Compile a binary expression with operator precedence
compileExpression = function(state: CompilerState, tokens: {string}, pos: TokenPosition): TokenPosition
    -- Check bounds
    if pos > #tokens then
        ErrorUtils.throwCompilerError(state, "SyntaxError", "Unexpected end of expression", "Check that all expressions are complete", "While parsing expression")
    end
    
    -- Parse the left operand
    pos = Expressions.compilePrimary(state, tokens, pos)
    
    -- Handle postfix operations (function calls, indexing, attribute access)
    while tokens[pos] do
        if tokens[pos] == "(" then
            -- Function call
            pos = Expressions.compileFunctionCall(state, tokens, pos)
        elseif tokens[pos] == "[" then
            -- Array/dictionary indexing
            pos = pos + 1  -- Skip '['
            
            -- Compile the index expression
            pos = compileExpression(state, tokens, pos)
            
            -- Expect ']'
            if tokens[pos] ~= "]" then
                ErrorUtils.expectedTokenError(state, "']'", tokens[pos], state.sourceLines)
            end
            pos = pos + 1  -- Skip ']'
            
            -- Emit indexing bytecode
            State.emit(state, opcodes.Opcodes.BINARY_SUBSCR)
        elseif tokens[pos] == "." then
            -- Attribute access (obj.attr)
            pos = pos + 1  -- Skip '.'
            
            if not tokens[pos] or not Utils.isIdentifier(tokens[pos]) then
                ErrorUtils.expectedTokenError(state, "identifier", tokens[pos], state.sourceLines)
            end
            
            local attrName = tokens[pos]
            pos = pos + 1
            
            -- Add attribute name to names table and emit LOAD_ATTR
            local nameIndex = State.addName(state, attrName)
            State.emit(state, opcodes.Opcodes.LOAD_ATTR, nameIndex)
        else
            break  -- No more postfix operations
        end
    end
    
    -- Handle binary operators with precedence
    while tokens[pos] and Utils.isBinaryOperator(tokens[pos]) do
        local operator = tokens[pos]
        pos = pos + 1
        
        -- Parse right operand
        pos = Expressions.compilePrimary(state, tokens, pos)
        
        -- Handle postfix operations on right operand
        while tokens[pos] do
            if tokens[pos] == "(" then
                pos = Expressions.compileFunctionCall(state, tokens, pos)
            elseif tokens[pos] == "[" then
                pos = pos + 1  -- Skip '['
                pos = compileExpression(state, tokens, pos)
                if tokens[pos] ~= "]" then
                    ErrorUtils.expectedTokenError(state, "']'", tokens[pos], state.sourceLines)
                end
                pos = pos + 1  -- Skip ']'
                State.emit(state, opcodes.Opcodes.BINARY_SUBSCR)
            elseif tokens[pos] == "." then
                pos = pos + 1  -- Skip '.'
                if not tokens[pos] or not Utils.isIdentifier(tokens[pos]) then
                    ErrorUtils.expectedTokenError(state, "identifier", tokens[pos], state.sourceLines)
                end
                local attrName = tokens[pos]
                pos = pos + 1
                local nameIndex = State.addName(state, attrName)
                State.emit(state, opcodes.Opcodes.LOAD_ATTR, nameIndex)
            else
                break
            end
        end
        
        -- Emit the appropriate binary operation
        if operator == "+" then
            State.emit(state, opcodes.Opcodes.BINARY_ADD)
        elseif operator == "-" then
            State.emit(state, opcodes.Opcodes.BINARY_SUB)
        elseif operator == "*" then
            State.emit(state, opcodes.Opcodes.BINARY_MUL)
        elseif operator == "/" then
            State.emit(state, opcodes.Opcodes.BINARY_DIV)
        elseif operator == "%" then
            State.emit(state, opcodes.Opcodes.BINARY_MOD)
        elseif operator == "==" then
            State.emit(state, opcodes.Opcodes.COMPARE_EQ)
        elseif operator == "!=" then
            State.emit(state, opcodes.Opcodes.COMPARE_NE)
        elseif operator == "<" then
            State.emit(state, opcodes.Opcodes.COMPARE_LT)
        elseif operator == ">" then
            State.emit(state, opcodes.Opcodes.COMPARE_GT)
        elseif operator == "<=" then
            State.emit(state, opcodes.Opcodes.COMPARE_LE)
        elseif operator == ">=" then
            State.emit(state, opcodes.Opcodes.COMPARE_GE)
        else
            ErrorUtils.throwCompilerError(state, "SyntaxError", "Unknown binary operator: " .. operator, "Check the operator syntax", "While parsing binary expression")
        end
    end
    
    return pos
end

-- Export the main expression compilation function
Expressions.compileExpression = compileExpression

return Expressions
