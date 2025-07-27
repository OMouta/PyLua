-- PyLua Compiler Error Utilities
-- Provides enhanced error reporting with line numbers and specific messages

local types = require('../../core/types')

type CompilerState = types.CompilerState

local ErrorUtils = {}

-- Enhanced compiler error types
export type CompilerError = {
    errorType: string,      -- Error category (e.g., "SyntaxError", "TypeError")
    message: string,        -- Primary error message
    line: number?,          -- Line number where error occurred
    column: number?,        -- Column position (future enhancement)
    sourceLine: string?,    -- The actual source line that caused the error
    suggestion: string?,    -- Helpful suggestion for fixing the error
    context: string?        -- Additional context about what the compiler was doing
}

-- Create a detailed compiler error
function ErrorUtils.createCompilerError(
    state: CompilerState, 
    errorType: string, 
    message: string, 
    suggestion: string?,
    context: string?
): CompilerError
    local error: CompilerError = {
        errorType = errorType,
        message = message,
        line = state.lineNumber,
        suggestion = suggestion,
        context = context
    }
    
    return error
end

-- Format a compiler error into a readable string
function ErrorUtils.formatCompilerError(error: CompilerError, sourceLines: {string}?): string
    local result = string.format("%s: %s", error.errorType, error.message)
    
    if error.line then
        result = result .. string.format("\n  at line %d", error.line)
        
        -- Add the source line if available
        if sourceLines and sourceLines[error.line] then
            local sourceLine = sourceLines[error.line]:match("^%s*(.-)%s*$") or ""
            if sourceLine ~= "" then
                result = result .. string.format(": %s", sourceLine)
            end
        end
    end
    
    if error.context then
        result = result .. string.format("\n  Context: %s", error.context)
    end
    
    if error.suggestion then
        result = result .. string.format("\n  Suggestion: %s", error.suggestion)
    end
    
    return result
end

-- Throw a compiler error with enhanced information
function ErrorUtils.throwCompilerError(
    state: CompilerState,
    errorType: string,
    message: string,
    suggestion: string?,
    context: string?,
    sourceLines: {string}?
)
    local compilerError = ErrorUtils.createCompilerError(state, errorType, message, suggestion, context)
    local errorMessage = ErrorUtils.formatCompilerError(compilerError, sourceLines)
    error(errorMessage)
end

-- Common syntax error patterns with helpful messages
function ErrorUtils.expectedTokenError(state: CompilerState, expected: string, found: string?, sourceLines: {string}?)
    local message = string.format("Expected %s", expected)
    if found then
        message = message .. string.format(" but found '%s'", found)
    end
    
    local suggestion = ErrorUtils.getTokenSuggestion(expected, found)
    
    ErrorUtils.throwCompilerError(
        state,
        "SyntaxError",
        message,
        suggestion,
        string.format("While parsing tokens, expected %s", expected),
        sourceLines
    )
end

-- Get helpful suggestions for common token errors
function ErrorUtils.getTokenSuggestion(expected: string, found: string?): string?
    if expected == ":" then
        return "All Python control structures (if, for, while, def) must end with a colon (:)"
    elseif expected == "(" then
        return "Function calls and definitions require parentheses"
    elseif expected == ")" then
        return "Make sure all opening parentheses have matching closing parentheses"
    elseif expected == "[" then
        return "List indexing and slicing require square brackets"
    elseif expected == "]" then
        return "Make sure all opening square brackets have matching closing brackets"
    elseif expected == "=" then
        return "Variable assignments require the equals sign (=)"
    elseif expected == "'def'" and found then
        return "Function definitions must start with the 'def' keyword"
    elseif expected == "'in'" then
        return "For loops require 'in' keyword: for variable in iterable:"
    elseif expected == "identifier" then
        return "Variable and function names must be valid identifiers (letters, numbers, underscores, cannot start with number)"
    end
    
    return nil
end

-- Specific error types for common compiler issues
function ErrorUtils.invalidAssignmentError(state: CompilerState, context: string, sourceLines: {string}?)
    ErrorUtils.throwCompilerError(
        state,
        "SyntaxError",
        "Invalid assignment statement",
        "Check that you have the correct syntax: variable = value or object[key] = value",
        context,
        sourceLines
    )
end

function ErrorUtils.invalidFunctionDefinitionError(state: CompilerState, issue: string, sourceLines: {string}?)
    local suggestions = {
        ["name"] = "Function names must be valid identifiers",
        ["parameters"] = "Parameters should be separated by commas and enclosed in parentheses",
        ["colon"] = "Function definitions must end with a colon (:)"
    }
    
    ErrorUtils.throwCompilerError(
        state,
        "SyntaxError",
        string.format("Invalid function definition: %s", issue),
        suggestions[issue] or "Check the function definition syntax: def function_name(parameters):",
        "While parsing function definition",
        sourceLines
    )
end

function ErrorUtils.invalidExpressionError(state: CompilerState, expression: string?, sourceLines: {string}?)
    local message = "Invalid expression"
    if expression then
        message = message .. string.format(": %s", expression)
    end
    
    ErrorUtils.throwCompilerError(
        state,
        "SyntaxError",
        message,
        "Check for proper operator precedence, matching parentheses, and valid variable names",
        "While parsing expression",
        sourceLines
    )
end

function ErrorUtils.unexpectedTokenError(state: CompilerState, token: string, sourceLines: {string}?)
    ErrorUtils.throwCompilerError(
        state,
        "SyntaxError",
        string.format("Unexpected token '%s'", token),
        "Check for typos, missing operators, or incorrect syntax",
        string.format("Encountered unexpected token '%s' while parsing", token),
        sourceLines
    )
end

return ErrorUtils
