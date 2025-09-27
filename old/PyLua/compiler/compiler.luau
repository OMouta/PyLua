-- PyLua Bytecode Compiler (Main Entry Point)
-- Compiles Python source code to PyLua bytecode
-- This is the main orchestrator that uses all the separate modules

local types = require('../core/types')
local tokenizer = require('./tokenizer')

-- Import all modules
local State = require('./modules/state')
local Utils = require('./modules/utils')
local Expressions = require('./modules/expressions')
local Statements = require('./modules/statements')
local Functions = require('./modules/functions')
local ControlFlow = require('./modules/control_flow')

type CompilerState = types.CompilerState
type Bytecode = types.Bytecode
type TokenPosition = types.TokenPosition

local Compiler = {}

-- Forward declarations for recursive compilation
local compileStatement: (CompilerState, {string}, TokenPosition) -> TokenPosition
local compileExpression: (CompilerState, {string}, TokenPosition) -> TokenPosition

-- Main statement compilation function
compileStatement = function(state: CompilerState, tokens: {string}, pos: TokenPosition): TokenPosition
    if not tokens[pos] then
        return pos
    end
    
    -- Check for function definition
    if tokens[pos] == "def" then
        return Functions.compileFunctionDefinition(state, tokens, pos)
    -- Otherwise delegate to statements module
    else
        return Statements.compileStatement(state, tokens, pos)
    end
end

-- Main expression compilation function
compileExpression = function(state: CompilerState, tokens: {string}, pos: TokenPosition): TokenPosition
    return Expressions.compileExpression(state, tokens, pos)
end

-- Set up the compile functions in modules that need them
ControlFlow.setCompileFunctions(compileStatement, compileExpression)

-- Main compilation function for multi-line blocks
local function compileLines(state: CompilerState, lines: {string}): CompilerState
    -- Store source lines in state for error reporting
    state.sourceLines = lines
    local i = 1
    while i <= #lines do
        state.lineNumber = i
        local line = lines[i]
        
        -- Fast path: check for empty lines and comments without regex
        local firstChar = line:match("^%s*(.)")
        if not firstChar or firstChar == "#" then
            -- Empty line or comment, skip
            i = i + 1
        else
            -- Only trim when we have content
            local trimmed = line:match("^%s*(.-)%s*$") or ""
            local tokens = tokenizer.tokenize(trimmed)
            
            -- Check if this line has unclosed delimiters (multi-line statement)
            if #tokens > 0 and Utils.hasUnclosedDelimiters(tokens) then
                -- Collect all tokens for the complete multi-line statement
                local completeTokens, endLine = Utils.collectMultiLineStatement(lines, i)
                compileStatement(state, completeTokens, 1)
                i = endLine + 1
            elseif #tokens > 0 then
                -- Check if this is a control flow statement (requires block parsing)
                if tokens[1] == "for" then
                    i = ControlFlow.compileForLoopBlock(state, lines, i)
                elseif tokens[1] == "while" then
                    i = ControlFlow.compileWhileLoopBlock(state, lines, i)
                elseif tokens[1] == "if" then
                    i = ControlFlow.compileIfStatementBlock(state, lines, i)
                elseif tokens[1] == "def" then
                    i = Functions.compileFunctionDefinitionBlock(state, lines, i)
                else
                    -- Simple statement - compile directly
                    compileStatement(state, tokens, 1)
                    i = i + 1
                end
            else
                i = i + 1
            end
        end
    end
    
    return state
end

-- Main compilation entry point
function Compiler.compile(sourceCode: string): Bytecode
    local state = State.createCompilerState()
    
    local lines: {string}
    if string.split then
        lines = sourceCode:split("\n")
        -- Remove carriage returns if present
        for i, line in ipairs(lines) do
            if line:sub(-1) == "\r" then
                lines[i] = line:sub(1, -2)
            end
        end
    else
        -- Fallback to gmatch
        lines = {}
        for line in sourceCode:gmatch("[^\r\n]+") do
            table.insert(lines, line)
        end
    end
    
    -- Compile all lines
    state = compileLines(state, lines)
    
    -- Return the bytecode structure
    local result: Bytecode = {
        constants = state.constants,
        names = state.names,
        code = state.code,
        sourceLines = lines  -- For debugging
    }
    return result
end

return Compiler
