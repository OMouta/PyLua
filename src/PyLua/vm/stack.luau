--!strict
-- PyLua Value Stack Management
-- Phase 4 - Stack operations for bytecode execution

local Stack = {}

-- Value stack for VM operations
export type Stack = {
    values: {any},
    top: number,
}

-- Create a new stack
function Stack.new(): Stack
    return {
        values = {},
        top = 0,
    }
end

-- Push value onto stack
function Stack.push(stack: Stack, value: any)
    stack.top = stack.top + 1
    stack.values[stack.top] = value
end

-- Pop value from stack
function Stack.pop(stack: Stack): any
    if stack.top <= 0 then
        error("Stack underflow", 2)
    end
    
    local value = stack.values[stack.top]
    stack.values[stack.top] = nil
    stack.top = stack.top - 1
    return value
end

-- Peek at top value without popping
function Stack.peek(stack: Stack): any
    if stack.top <= 0 then
        error("Stack is empty", 2)
    end
    
    return stack.values[stack.top]
end

-- Get stack size
function Stack.size(stack: Stack): number
    return stack.top
end

-- Check if stack is empty
function Stack.isEmpty(stack: Stack): boolean
    return stack.top <= 0
end

return Stack
