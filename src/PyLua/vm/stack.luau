local Stack = {}

-- Value stack for VM operations
export type Stack = {
	values: { any },
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

-- Rotate top 2 stack items (equivalent to ROT_TWO)
function Stack.rotTwo(stack: Stack)
	if stack.top < 2 then
		error("Not enough items on stack for ROT_TWO", 2)
	end

	local a = stack.values[stack.top]
	local b = stack.values[stack.top - 1]

	stack.values[stack.top] = b
	stack.values[stack.top - 1] = a
end

-- Rotate top 3 stack items (equivalent to ROT_THREE)
function Stack.rotThree(stack: Stack)
	if stack.top < 3 then
		error("Not enough items on stack for ROT_THREE", 2)
	end

	local a = stack.values[stack.top]
	local b = stack.values[stack.top - 1]
	local c = stack.values[stack.top - 2]

	stack.values[stack.top] = c
	stack.values[stack.top - 1] = a
	stack.values[stack.top - 2] = b
end

-- Duplicate top stack item (equivalent to DUP_TOP)
function Stack.duplicate(stack: Stack)
	local value = Stack.peek(stack)
	Stack.push(stack, value)
end

-- Pop multiple values and return as array
function Stack.popN(stack: Stack, n: number): { any }
	if n <= 0 then
		return {}
	end

	if stack.top < n then
		error("Not enough items on stack to pop " .. n, 2)
	end

	local values: { any } = {}
	for i = 1, n do
		values[i] = Stack.pop(stack) -- Keep popped order (top first)
	end

	return values
end

-- Get item at relative position from top (0 = top, 1 = second from top, etc.)
function Stack.getRelative(stack: Stack, offset: number): any
	local index = stack.top - offset
	if index <= 0 or index > stack.top then
		error("Stack index out of bounds", 2)
	end
	return stack.values[index]
end

return Stack
