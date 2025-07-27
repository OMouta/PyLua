-- PyLua Statement Compilation
-- Handles compilation of statements including assignments and expression statements

local types = require('../../core/types')
local opcodes = require('../../vm/opcodes')
local State = require('./state')
local Utils = require('./utils')
local Expressions = require('./expressions')
local ErrorUtils = require('./error_utils')

type CompilerState = types.CompilerState
type TokenPosition = types.TokenPosition

local Statements = {}

-- Compile an assignment statement
function Statements.compileAssignment(state: CompilerState, tokens: {string}, pos: TokenPosition): TokenPosition
    -- Parse the left-hand side to determine assignment type
    
    -- Check if it's a simple variable assignment (var = ...) or indexing assignment (obj[key] = ...)
    if Utils.isIdentifier(tokens[pos]) and tokens[pos + 1] == "=" then
        -- Simple variable assignment: var = value
        local varName = tokens[pos]
        pos = pos + 2  -- Skip variable name and '='
        
        -- Compile the right-hand side expression
        pos = Expressions.compileExpression(state, tokens, pos)
        
        -- Store the value in the variable
        local nameIndex = State.addName(state, varName)
        State.emit(state, opcodes.Opcodes.STORE_NAME, nameIndex)
        
        return pos
    else
        -- Check for indexing assignment: obj[key] = value
        local savedPos = pos
        local foundIndexing = false
        local equalsPos = nil
        
        -- Scan to find the assignment pattern
        while pos <= #tokens do
            if tokens[pos] == "=" then
                equalsPos = pos
                break
            elseif tokens[pos] == "[" then
                foundIndexing = true
            end
            pos = pos + 1
        end
        
        if foundIndexing and equalsPos then
            -- Indexing assignment: obj[key] = value
            pos = savedPos
            
            -- Compile the object expression (everything before '[')
            local objStart = pos
            while tokens[pos] and tokens[pos] ~= "[" do
                pos = pos + 1
            end
            
            -- Compile object expression
            local objTokens = {}
            for i = objStart, pos - 1 do
                table.insert(objTokens, tokens[i])
            end
            Expressions.compileExpression(state, objTokens, 1)
            
            -- Skip '['
            if tokens[pos] ~= "[" then
                ErrorUtils.expectedTokenError(state, "'['", tokens[pos], state.sourceLines)
            end
            pos = pos + 1
            
            -- Compile the index expression
            local indexStart = pos
            local bracketCount = 1
            while tokens[pos] and bracketCount > 0 do
                if tokens[pos] == "[" then
                    bracketCount = bracketCount + 1
                elseif tokens[pos] == "]" then
                    bracketCount = bracketCount - 1
                end
                if bracketCount > 0 then
                    pos = pos + 1
                end
            end
            
            local indexTokens = {}
            for i = indexStart, pos - 1 do
                table.insert(indexTokens, tokens[i])
            end
            Expressions.compileExpression(state, indexTokens, 1)
            
            -- Skip ']'
            if tokens[pos] ~= "]" then
                ErrorUtils.expectedTokenError(state, "']'", tokens[pos], state.sourceLines)
            end
            pos = pos + 1
            
            -- Skip '='
            if tokens[pos] ~= "=" then
                ErrorUtils.expectedTokenError(state, "'='", tokens[pos], state.sourceLines)
            end
            pos = pos + 1
            
            -- Compile the right-hand side expression
            pos = Expressions.compileExpression(state, tokens, pos)
            
            -- Emit store subscript instruction
            State.emit(state, opcodes.Opcodes.STORE_SUBSCR)
            
            return pos
        else
            ErrorUtils.invalidAssignmentError(state, "Invalid assignment pattern detected", state.sourceLines)
            return pos -- Ensure a return value for all code paths
        end
    end
end

-- Simple for loop compilation (inline)
function Statements.compileForLoop(state: CompilerState, tokens: {string}, pos: TokenPosition): TokenPosition
    -- for var in iterable:
    if tokens[pos] ~= "for" then
        ErrorUtils.expectedTokenError(state, "'for'", tokens[pos], state.sourceLines)
    end
    pos = pos + 1
    
    -- Get the loop variable name
    local loopVar = tokens[pos]
    if not Utils.isIdentifier(loopVar) then
        ErrorUtils.expectedTokenError(state, "identifier", tokens[pos], state.sourceLines)
    end
    pos = pos + 1
    
    -- Expect 'in'
    if tokens[pos] ~= "in" then
        ErrorUtils.expectedTokenError(state, "'in'", tokens[pos], state.sourceLines)
    end
    pos = pos + 1
    
    -- Compile the iterable expression
    pos = Expressions.compileExpression(state, tokens, pos)
    
    -- Expect ':'
    if tokens[pos] ~= ":" then
        ErrorUtils.expectedTokenError(state, "':'", tokens[pos], state.sourceLines)
    end
    pos = pos + 1
    
    -- Get iterator from the iterable
    State.emit(state, opcodes.Opcodes.GET_ITER)
    
    -- Mark the loop start position
    local loopStart = #state.code
    
    -- Try to get next value from iterator
    State.emit(state, opcodes.Opcodes.FOR_ITER, 0) -- Will patch jump target later
    local forIterInstruction = #state.code - 1
    
    -- Store the loop value in the loop variable
    local loopVarIndex = State.addName(state, loopVar)
    State.emit(state, opcodes.Opcodes.STORE_NAME, loopVarIndex)
    
    -- For now, we'll create a simple placeholder loop body
    -- In a full implementation, we'd need to parse indented blocks
    -- But for testing, let's assume single-line loop bodies
    
    -- Jump back to loop start
    State.emit(state, opcodes.Opcodes.JUMP, loopStart)
    
    -- Patch the FOR_ITER jump target to exit the loop
    local exitTarget = #state.code
    state.code[forIterInstruction + 1].arg = exitTarget
    
    return pos
end

-- Compile a single statement
function Statements.compileStatement(state: CompilerState, tokens: {string}, pos: TokenPosition): TokenPosition
    if not tokens[pos] then
        return pos
    end
    
    -- Check for control flow statements
    if tokens[pos] == "for" then
        return Statements.compileForLoop(state, tokens, pos)
    -- Check if this is an assignment (variable = expression OR obj[key] = expression)
    elseif Utils.isIdentifier(tokens[pos]) then
        -- Look ahead to determine if this is an assignment
        local checkPos = pos + 1
        local foundEquals = false
        
        -- Scan forward to look for '=' (allowing for indexing syntax)
        while checkPos <= #tokens do
            if tokens[checkPos] == "=" then
                foundEquals = true
                break
            elseif tokens[checkPos] == "(" then
                -- If we hit a function call, it's not an assignment
                break
            end
            checkPos = checkPos + 1
        end
        
        if foundEquals then
            return Statements.compileAssignment(state, tokens, pos)
        else
            -- Expression statement (like function calls)
            pos = Expressions.compileExpression(state, tokens, pos)
            -- Pop the result since it's not being assigned
            State.emit(state, opcodes.Opcodes.POP_TOP)
            return pos
        end
    else
        -- Expression statement (like function calls)
        pos = Expressions.compileExpression(state, tokens, pos)
        -- Pop the result since it's not being assigned
        State.emit(state, opcodes.Opcodes.POP_TOP)
        return pos
    end
end

return Statements
