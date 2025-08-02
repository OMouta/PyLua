-- PyLua Control Flow Compilation
-- Handles compilation of control flow statements (if/elif/else, while, for loops)

local types = require('../../core/types')
local opcodes = require('../../vm/opcodes')
local tokenizer = require('../tokenizer')
local State = require('./state')
local _Utils = require('./utils')
local ErrorUtils = require('./error_utils')

type CompilerState = types.CompilerState

local ControlFlow = {}

-- Forward declarations to handle circular dependencies
local compileStatement: ((CompilerState, {string}, number) -> number)?
local compileExpression: ((CompilerState, {string}, number) -> number)?

-- Set the compile functions (to be called from main compiler)
function ControlFlow.setCompileFunctions(stmtFunc: any, exprFunc: any)
    compileStatement = stmtFunc
    compileExpression = exprFunc
end

-- Compile an if/elif/else statement with blocks
function ControlFlow.compileIfStatementBlock(state: CompilerState, lines: {string}, startLine: number): number
    local endJumps = {}  -- Jumps to the end of the entire if statement
    local currentLine = startLine
    
    while currentLine <= #lines do
        local line = lines[currentLine]
        local trimmedLine = line:match("^%s*(.-)%s*$") or ""
        local tokens = tokenizer.tokenize(trimmedLine)
        
        if #tokens == 0 then
            currentLine = currentLine + 1
            break
        end
        
        local keyword = tokens[1]
        
        if keyword == "if" or keyword == "elif" then
            -- Parse: if/elif condition:
            local conditionTokens = {}
            local pos = 2
            while pos <= #tokens and tokens[pos] ~= ":" do
                table.insert(conditionTokens, tokens[pos])
                pos = pos + 1
            end
            
            if pos > #tokens or tokens[pos] ~= ":" then
                ErrorUtils.expectedTokenError(state, "':'", tokens[pos], state.sourceLines)
            end
            
            if #conditionTokens == 0 then
                ErrorUtils.throwCompilerError(state, "SyntaxError", keyword .. " statement must have a condition", "Add a condition expression", "While parsing " .. keyword .. " statement")
            end
            
            -- Compile the condition expression
            if compileExpression then
                compileExpression(state, conditionTokens, 1)
            else
                -- Fallback: load a placeholder constant
                local constIndex = State.addConstant(state, true)
                State.emit(state, opcodes.Opcodes.LOAD_CONST, constIndex)
            end
            
            -- Jump if condition is false (will patch target later)
            State.emit(state, opcodes.Opcodes.JUMP_IF_FALSE, 0)
            local conditionJump = #state.code - 1
            
            -- Compile the indented block for this if/elif
            currentLine = currentLine + 1
            local baseIndent = nil
            
            while currentLine <= #lines do
                local blockLine = lines[currentLine]
                local indent = blockLine:match("^(%s*)") or ""
                local trimmed = blockLine:match("^%s*(.-)%s*$") or ""
                
                -- Skip empty lines
                if trimmed == "" then
                    currentLine = currentLine + 1
                elseif #indent > 0 then
                    -- First indented line sets the base indentation
                    if not baseIndent then
                        baseIndent = #indent
                    end
                    -- If indentation matches the block level, compile this line
                    if #indent >= baseIndent then
                        local blockTokens = tokenizer.tokenize(trimmed)
                        if #blockTokens > 0 then
                            -- Check if this is a nested control structure
                            if blockTokens[1] == "if" then
                                -- Handle nested if statement
                                currentLine = ControlFlow.compileIfStatementBlock(state, lines, currentLine)
                            elseif blockTokens[1] == "while" then
                                -- Handle nested while loop
                                currentLine = ControlFlow.compileWhileLoopBlock(state, lines, currentLine)
                            elseif blockTokens[1] == "for" then
                                -- Handle nested for loop
                                currentLine = ControlFlow.compileForLoopBlock(state, lines, currentLine)
                            else
                                -- Regular statement
                                state.lineNumber = currentLine
                                if compileStatement then
                                    compileStatement(state, blockTokens, 1)
                                else
                                    -- Fallback: nop
                                    local constIndex = State.addConstant(state, "PLACEHOLDER_STMT")
                                    State.emit(state, opcodes.Opcodes.LOAD_CONST, constIndex)
                                    State.emit(state, opcodes.Opcodes.POP_TOP)
                                end
                                currentLine = currentLine + 1
                            end
                        else
                            currentLine = currentLine + 1
                        end
                    else
                        -- Indentation decreased, end of block
                        break
                    end
                else
                    -- No indentation, check if it's elif/else
                    local nextTokens = tokenizer.tokenize(trimmed)
                    if nextTokens[1] == "elif" or nextTokens[1] == "else" then
                        break  -- Continue to handle elif/else
                    else
                        break  -- End of if statement
                    end
                end
            end
            
            -- After the block, jump to the end of the entire if statement
            -- (to skip other elif/else clauses)
            State.emit(state, opcodes.Opcodes.JUMP, 0)
            table.insert(endJumps, #state.code - 1)
            
            -- Patch the condition jump to point here (start of next clause)
            local nextClauseTarget = #state.code
            state.code[conditionJump + 1].arg = nextClauseTarget
            
            -- Check if we have more elif/else clauses
            if currentLine <= #lines then
                local nextLine = lines[currentLine]
                if nextLine then
                    local nextTrimmed = nextLine:match("^%s*(.-)%s*$") or ""
                    local nextTokens = tokenizer.tokenize(nextTrimmed)
                    if nextTokens[1] == "elif" or nextTokens[1] == "else" then
                        -- Continue with next clause
                    else
                        -- End of if statement
                        break
                    end
                else
                    break
                end
            else
                break
            end
            
        elseif keyword == "else" then
            -- Parse: else:
            if #tokens < 2 or tokens[2] ~= ":" then
                ErrorUtils.expectedTokenError(state, "':'", tokens[2], state.sourceLines)
            end
            
            -- Compile the else block (similar to if block)
            currentLine = ControlFlow.compileElseBlock(state, lines, currentLine + 1)
            
            break  -- else is always the last clause
        else
            break  -- Not an if/elif/else statement
        end
    end
    
    -- Patch all the "jump to end" instructions to point to the end
    local endTarget = #state.code
    for _, jumpIndex in ipairs(endJumps) do
        state.code[jumpIndex + 1].arg = endTarget
    end
    
    return currentLine
end

-- Helper function to compile else block
function ControlFlow.compileElseBlock(state: CompilerState, lines: {string}, startLine: number): number
    local currentLine = startLine
    local baseIndent = nil
    
    while currentLine <= #lines do
        local blockLine = lines[currentLine]
        local indent = blockLine:match("^(%s*)") or ""
        local trimmed = blockLine:match("^%s*(.-)%s*$") or ""
        
        -- Skip empty lines
        if trimmed == "" then
            currentLine = currentLine + 1
        elseif #indent > 0 then
            -- First indented line sets the base indentation
            if not baseIndent then
                baseIndent = #indent
            end
            -- If indentation matches the block level, compile this line
            if #indent >= baseIndent then
                local blockTokens = tokenizer.tokenize(trimmed)
                if #blockTokens > 0 then
                    -- Check if this is a nested control structure
                    if blockTokens[1] == "if" then
                        -- Handle nested if statement
                        currentLine = ControlFlow.compileIfStatementBlock(state, lines, currentLine)
                    elseif blockTokens[1] == "while" then
                        -- Handle nested while loop
                        currentLine = ControlFlow.compileWhileLoopBlock(state, lines, currentLine)
                    elseif blockTokens[1] == "for" then
                        -- Handle nested for loop
                        currentLine = ControlFlow.compileForLoopBlock(state, lines, currentLine)
                    else
                        -- Regular statement
                        state.lineNumber = currentLine
                        if compileStatement then
                            compileStatement(state, blockTokens, 1)
                        else
                            -- Fallback: nop
                            local constIndex = State.addConstant(state, "PLACEHOLDER_STMT")
                            State.emit(state, opcodes.Opcodes.LOAD_CONST, constIndex)
                            State.emit(state, opcodes.Opcodes.POP_TOP)
                        end
                        currentLine = currentLine + 1
                    end
                else
                    currentLine = currentLine + 1
                end
            else
                -- Indentation decreased, end of block
                break
            end
        else
            -- No indentation, end of else block
            break
        end
    end
    
    return currentLine
end

-- Compile a while loop with a block of statements
function ControlFlow.compileWhileLoopBlock(state: CompilerState, lines: {string}, startLine: number): number
    local line = lines[startLine]
    local trimmedLine = line:match("^%s*(.-)%s*$") or ""
    local tokens = tokenizer.tokenize(trimmedLine)
    
    -- Parse: while condition:
    if tokens[1] ~= "while" then
        ErrorUtils.expectedTokenError(state, "'while'", tokens[1], state.sourceLines)
    end
    
    -- Parse the condition expression (everything until ':')
    local conditionTokens = {}
    local pos = 2
    while pos <= #tokens and tokens[pos] ~= ":" do
        table.insert(conditionTokens, tokens[pos])
        pos = pos + 1
    end
    
    if tokens[pos] ~= ":" then
        ErrorUtils.expectedTokenError(state, "':'", tokens[pos], state.sourceLines)
    end
    
    if #conditionTokens == 0 then
        ErrorUtils.throwCompilerError(state, "SyntaxError", "While loop must have a condition", "Add a condition expression", "While parsing while statement")
    end
    
    -- Mark the loop start position (where we'll jump back to)
    local loopStart = #state.code
    
    -- Compile the condition expression
    if compileExpression then
        compileExpression(state, conditionTokens, 1)
    else
        -- Fallback: load a placeholder constant
        local constIndex = State.addConstant(state, true)
        State.emit(state, opcodes.Opcodes.LOAD_CONST, constIndex)
    end
    
    -- Jump if condition is false (will patch the target later)
    State.emit(state, opcodes.Opcodes.JUMP_IF_FALSE, 0)
    local exitJumpInstruction = #state.code - 1
    
    -- Find and compile the indented block
    local currentLine = startLine + 1
    local baseIndent = nil
    
    while currentLine <= #lines do
        local blockLine = lines[currentLine]
        local indent = blockLine:match("^(%s*)") or ""
        local trimmed = blockLine:match("^%s*(.-)%s*$") or ""
        
        -- Skip empty lines
        if trimmed == "" then
            currentLine = currentLine + 1
        -- Check if this line is part of the block
        elseif #indent > 0 then
            -- First indented line sets the base indentation
            if not baseIndent then
                baseIndent = #indent
            end
            -- If indentation matches the block level, compile this line
            if #indent >= baseIndent then
                local blockTokens = tokenizer.tokenize(trimmed)
                if #blockTokens > 0 then
                    -- Check if this is a nested control structure
                    if blockTokens[1] == "if" then
                        -- Handle nested if statement
                        currentLine = ControlFlow.compileIfStatementBlock(state, lines, currentLine)
                    elseif blockTokens[1] == "while" then
                        -- Handle nested while loop
                        currentLine = ControlFlow.compileWhileLoopBlock(state, lines, currentLine)
                    elseif blockTokens[1] == "for" then
                        -- Handle nested for loop
                        currentLine = ControlFlow.compileForLoopBlock(state, lines, currentLine)
                    else
                        -- Regular statement
                        state.lineNumber = currentLine
                        if compileStatement then
                            compileStatement(state, blockTokens, 1)
                        else
                            -- Fallback: nop
                            local constIndex = State.addConstant(state, "PLACEHOLDER_STMT")
                            State.emit(state, opcodes.Opcodes.LOAD_CONST, constIndex)
                            State.emit(state, opcodes.Opcodes.POP_TOP)
                        end
                        currentLine = currentLine + 1
                    end
                else
                    currentLine = currentLine + 1
                end
            else
                -- Indentation decreased, end of block
                break
            end
        else
            -- No indentation, end of block
            break
        end
    end
    
    -- Jump back to the beginning of the loop
    State.emit(state, opcodes.Opcodes.JUMP, loopStart)
    
    -- Patch the exit jump target
    local exitTarget = #state.code
    state.code[exitJumpInstruction + 1].arg = exitTarget
    
    return currentLine
end

-- Compile a for loop with a block of statements  
function ControlFlow.compileForLoopBlock(state: CompilerState, lines: {string}, startLine: number): number
    local line = lines[startLine]
    local trimmedLine = line:match("^%s*(.-)%s*$") or ""
    local tokens = tokenizer.tokenize(trimmedLine)
    
    -- Parse: for var in iterable:
    if tokens[1] ~= "for" then
        ErrorUtils.expectedTokenError(state, "'for'", tokens[1], state.sourceLines)
    end
    
    -- Get the loop variable name
    local loopVar = tokens[2]
    if not loopVar then
        ErrorUtils.expectedTokenError(state, "identifier", nil, state.sourceLines)
    end
    
    -- Expect 'in'
    if tokens[3] ~= "in" then
        ErrorUtils.expectedTokenError(state, "'in'", tokens[3], state.sourceLines)
    end
    
    -- Parse the iterable expression (rest of the tokens until ':')
    local iterableTokens = {}
    local pos = 4
    while pos <= #tokens and tokens[pos] ~= ":" do
        table.insert(iterableTokens, tokens[pos])
        pos = pos + 1
    end
    
    if tokens[pos] ~= ":" then
        ErrorUtils.expectedTokenError(state, "':'", tokens[pos], state.sourceLines)
    end
    
    -- Compile the iterable expression
    if compileExpression then
        compileExpression(state, iterableTokens, 1)
    else
        -- Fallback: load a placeholder constant
        local constIndex = State.addConstant(state, {1, 2, 3})
        State.emit(state, opcodes.Opcodes.LOAD_CONST, constIndex)
    end
    
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
    
    -- Find and compile the indented block
    local currentLine = startLine + 1
    local baseIndent = nil
    
    while currentLine <= #lines do
        local blockLine = lines[currentLine]
        local indent = blockLine:match("^(%s*)") or ""
        local trimmed = blockLine:match("^%s*(.-)%s*$") or ""
        
        -- Skip empty lines
        if trimmed == "" then
            currentLine = currentLine + 1
        -- Check if this line is part of the block
        elseif #indent > 0 then
            -- First indented line sets the base indentation
            if not baseIndent then
                baseIndent = #indent
            end
            -- If indentation matches the block level, compile this line
            if #indent >= baseIndent then
                local blockTokens = tokenizer.tokenize(trimmed)
                if #blockTokens > 0 then
                    -- Check if this is a nested control structure
                    if blockTokens[1] == "if" then
                        -- Handle nested if statement
                        currentLine = ControlFlow.compileIfStatementBlock(state, lines, currentLine)
                    elseif blockTokens[1] == "while" then
                        -- Handle nested while loop
                        currentLine = ControlFlow.compileWhileLoopBlock(state, lines, currentLine)
                    elseif blockTokens[1] == "for" then
                        -- Handle nested for loop
                        currentLine = ControlFlow.compileForLoopBlock(state, lines, currentLine)
                    else
                        -- Regular statement
                        state.lineNumber = currentLine
                        if compileStatement then
                            compileStatement(state, blockTokens, 1)
                        else
                            -- Fallback: nop
                            local constIndex = State.addConstant(state, "PLACEHOLDER_STMT")
                            State.emit(state, opcodes.Opcodes.LOAD_CONST, constIndex)
                            State.emit(state, opcodes.Opcodes.POP_TOP)
                        end
                        currentLine = currentLine + 1
                    end
                else
                    currentLine = currentLine + 1
                end
            else
                -- Indentation decreased, end of block
                break
            end
        else
            -- No indentation, end of block
            break
        end
    end
    
    -- Jump back to loop start
    State.emit(state, opcodes.Opcodes.JUMP, loopStart)
    
    -- Patch the FOR_ITER jump target to exit the loop
    local exitTarget = #state.code
    state.code[forIterInstruction + 1].arg = exitTarget
    
    return currentLine
end

return ControlFlow
