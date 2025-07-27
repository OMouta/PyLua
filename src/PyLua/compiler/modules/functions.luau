-- PyLua Function Definition Compilation
-- Handles compilation of function definitions with proper block parsing

local types = require('../../core/types')
local opcodes = require('../../vm/opcodes')
local tokenizer = require('../tokenizer')
local State = require('./state')
local Utils = require('./utils')
local ErrorUtils = require('./error_utils')

type CompilerState = types.CompilerState
type TokenPosition = types.TokenPosition
type Bytecode = types.Bytecode

local Functions = {}

-- Simple function definition compilation (inline)
function Functions.compileFunctionDefinition(state: CompilerState, tokens: {string}, pos: TokenPosition): TokenPosition
    -- def function_name(param1, param2, ...):
    if tokens[pos] ~= "def" then
        ErrorUtils.expectedTokenError(state, "'def'", tokens[pos], state.sourceLines)
    end
    pos = pos + 1
    
    -- Get function name
    local functionName = tokens[pos]
    if not Utils.isIdentifier(functionName) then
        ErrorUtils.expectedTokenError(state, "identifier", tokens[pos], state.sourceLines)
    end
    pos = pos + 1
    
    -- Expect '('
    if tokens[pos] ~= "(" then
        ErrorUtils.expectedTokenError(state, "'('", tokens[pos], state.sourceLines)
    end
    pos = pos + 1
    
    -- Parse parameters
    local parameters = {}
    while tokens[pos] and tokens[pos] ~= ")" do
        if #parameters > 0 then
            if tokens[pos] ~= "," then
                ErrorUtils.expectedTokenError(state, "','", tokens[pos], state.sourceLines)
            end
            pos = pos + 1
        end
        
        if not Utils.isIdentifier(tokens[pos]) then
            ErrorUtils.expectedTokenError(state, "identifier", tokens[pos], state.sourceLines)
        end
        
        table.insert(parameters, tokens[pos])
        pos = pos + 1
    end
    
    -- Expect ')'
    if tokens[pos] ~= ")" then
        ErrorUtils.expectedTokenError(state, "')'", tokens[pos], state.sourceLines)
    end
    pos = pos + 1
    
    -- Expect ':'
    if tokens[pos] ~= ":" then
        ErrorUtils.expectedTokenError(state, "':'", tokens[pos], state.sourceLines)
    end
    pos = pos + 1
    
    -- For now, create a placeholder function object
    -- In a full implementation, we'd compile the function body as separate bytecode
    local nameIndex = State.addName(state, functionName)
    
    -- Create a placeholder bytecode structure
    local placeholderBytecode: Bytecode = {
        constants = {},
        names = {},
        code = {}
    }
    
    -- Create MAKE_FUNCTION instruction with function details
    local instruction = {
        op = opcodes.Opcodes.MAKE_FUNCTION,
        name = functionName,
        parameters = parameters,
        bytecode = placeholderBytecode,
        defaults = {},
        closure = {},
        arg = nameIndex, -- Use nameIndex as the arg for consistency
        line = state.lineNumber
    }
    table.insert(state.code, instruction)
    
    -- Store function in variable
    State.emit(state, opcodes.Opcodes.STORE_NAME, nameIndex)
    
    return pos
end

-- Function definition compilation with block parsing
function Functions.compileFunctionDefinitionBlock(state: CompilerState, lines: {string}, startLine: number): number
    local line = lines[startLine]
    local trimmedLine = line:match("^%s*(.-)%s*$") or ""
    local tokens = tokenizer.tokenize(trimmedLine)
    
    -- Parse the function definition header
    local pos = 1
    if tokens[pos] ~= "def" then
        ErrorUtils.expectedTokenError(state, "'def'", tokens[pos], state.sourceLines)
    end
    pos = pos + 1
    
    -- Get function name
    local functionName = tokens[pos]
    if not Utils.isIdentifier(functionName) then
        ErrorUtils.expectedTokenError(state, "identifier", tokens[pos], state.sourceLines)
    end
    pos = pos + 1
    
    -- Expect '('
    if tokens[pos] ~= "(" then
        ErrorUtils.expectedTokenError(state, "'('", tokens[pos], state.sourceLines)
    end
    pos = pos + 1
    
    -- Parse parameters
    local parameters = {}
    while tokens[pos] and tokens[pos] ~= ")" do
        if #parameters > 0 then
            if tokens[pos] ~= "," then
                ErrorUtils.expectedTokenError(state, "','", tokens[pos], state.sourceLines)
            end
            pos = pos + 1
        end
        
        if not Utils.isIdentifier(tokens[pos]) then
            ErrorUtils.expectedTokenError(state, "identifier", tokens[pos], state.sourceLines)
        end
        
        table.insert(parameters, tokens[pos])
        pos = pos + 1
    end
    
    -- Expect ')'
    if tokens[pos] ~= ")" then
        ErrorUtils.expectedTokenError(state, "')'", tokens[pos], state.sourceLines)
    end
    pos = pos + 1
    
    -- Expect ':'
    if tokens[pos] ~= ":" then
        ErrorUtils.expectedTokenError(state, "':'", tokens[pos], state.sourceLines)
    end
    
    -- Create a new compiler state for the function body
    local functionState = State.createCompilerState()
    
    -- We need to import the compile functions for function body compilation
    -- This creates a circular dependency issue, so we'll handle this differently
    -- For now, we'll create a simple placeholder implementation
    
    -- Compile the function body
    local currentLine = startLine + 1
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
                    -- Check for return statement
                    if blockTokens[1] == "return" then
                        -- Compile return expression
                        if #blockTokens > 1 then
                            local returnTokens = {}
                            for i = 2, #blockTokens do
                                table.insert(returnTokens, blockTokens[i])
                            end
                            -- Note: This requires compileExpression which would create circular dependency
                            -- We'll handle this in the main compiler
                            local constIndex = State.addConstant(functionState, "PLACEHOLDER_RETURN")
                            State.emit(functionState, opcodes.Opcodes.LOAD_CONST, constIndex)
                        else
                            -- Return None
                            local constIndex = State.addConstant(functionState, nil)
                            State.emit(functionState, opcodes.Opcodes.LOAD_CONST, constIndex)
                        end
                        State.emit(functionState, opcodes.Opcodes.RETURN_VALUE)
                    else
                        -- Regular statement in function body - placeholder for now
                        functionState.lineNumber = currentLine
                        local constIndex = State.addConstant(functionState, "PLACEHOLDER_STATEMENT")
                        State.emit(functionState, opcodes.Opcodes.LOAD_CONST, constIndex)
                        State.emit(functionState, opcodes.Opcodes.POP_TOP)
                    end
                    currentLine = currentLine + 1
                else
                    currentLine = currentLine + 1
                end
            else
                -- Indentation decreased, end of function body
                break
            end
        else
            -- No indentation, end of function body
            break
        end
    end
    
    -- If no explicit return, add implicit return None
    if #functionState.code == 0 or functionState.code[#functionState.code].op ~= opcodes.Opcodes.RETURN_VALUE then
        local constIndex = State.addConstant(functionState, nil)
        State.emit(functionState, opcodes.Opcodes.LOAD_CONST, constIndex)
        State.emit(functionState, opcodes.Opcodes.RETURN_VALUE)
    end
    
    -- Create MAKE_FUNCTION instruction with complete function bytecode
    local nameIndex = State.addName(state, functionName)
    local instruction = {
        op = opcodes.Opcodes.MAKE_FUNCTION,
        name = functionName,
        parameters = parameters,
        bytecode = {
            constants = functionState.constants,
            names = functionState.names,
            code = functionState.code
        },
        defaults = {},
        closure = {},
        arg = nameIndex, -- Use nameIndex as the arg for consistency
        line = state.lineNumber
    }
    table.insert(state.code, instruction)
    
    -- Store function in variable
    State.emit(state, opcodes.Opcodes.STORE_NAME, nameIndex)
    
    return currentLine
end

return Functions
