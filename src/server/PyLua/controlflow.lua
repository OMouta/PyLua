-- PyLua Control Flow
-- Handles conditional statements and loops

local ControlFlow = {}

-- Execute an if statement
function ControlFlow.executeIf(condition, ifBody, elseBody, evaluator, builtins, variables)
	-- Evaluate the condition
	local isTrue = evaluator.evaluateCondition(condition, variables, builtins)
	
	if isTrue then
		-- Execute if body
		for _, statement in ipairs(ifBody) do
			evaluator.executeStatement(statement, builtins, variables)
		end
	elseif elseBody then
		-- Execute else body
		for _, statement in ipairs(elseBody) do
			evaluator.executeStatement(statement, builtins, variables)
		end
	end
end

-- Execute an if/elif/else chain
function ControlFlow.executeIfChain(ifCondition, ifBody, elifChain, elseBody, evaluator, builtins, variables)
	-- Evaluate the if condition first
	local isTrue = evaluator.evaluateCondition(ifCondition, variables, builtins)
	
	if isTrue then
		-- Execute if body
		for _, statement in ipairs(ifBody) do
			evaluator.executeStatement(statement, builtins, variables)
		end
		return
	end
	
	-- Check elif conditions
	if elifChain then
		for _, elifBlock in ipairs(elifChain) do
			local elifTrue = evaluator.evaluateCondition(elifBlock.condition, variables, builtins)
			if elifTrue then
				-- Execute elif body
				for _, statement in ipairs(elifBlock.body) do
					evaluator.executeStatement(statement, builtins, variables)
				end
				return
			end
		end
	end
	
	-- If no conditions were true, execute else body
	if elseBody then
		for _, statement in ipairs(elseBody) do
			evaluator.executeStatement(statement, builtins, variables)
		end
	end
end

-- Execute a for loop
function ControlFlow.executeFor(variable, iterable, body, evaluator, builtins, variables)
	-- Debug the iterable string
	print("DEBUG: For loop iterable string:", iterable)
	
	-- Evaluate the iterable
	local iterableValue = evaluator.evaluateExpression(iterable, variables, builtins)
	
	-- Debug output to see what we're iterating over
	print("DEBUG: Iterating over:", type(iterableValue), "value:", iterableValue)
	
	-- Handle different types of iterables
	if type(iterableValue) == "table" then
		-- Iterate over a list/table
		for _, value in ipairs(iterableValue) do
			-- Set the loop variable
			variables.set(variable, value)
			
			-- Execute the loop body
			for _, statement in ipairs(body) do
				evaluator.executeStatement(statement, builtins, variables)
			end
		end
	elseif type(iterableValue) == "string" then
		-- Iterate over string characters
		for i = 1, #iterableValue do
			local char = iterableValue:sub(i, i)
			variables.set(variable, char)
			
			-- Execute the loop body
			for _, statement in ipairs(body) do
				evaluator.executeStatement(statement, builtins, variables)
			end
		end
	else
		error("Object is not iterable: " .. type(iterableValue) .. " (value: " .. tostring(iterableValue) .. ")")
	end
end

-- Execute a while loop
function ControlFlow.executeWhile(condition, body, evaluator, builtins, variables)
	local maxIterations = 10000 -- Safety limit to prevent infinite loops
	local iterations = 0
	
	while evaluator.evaluateCondition(condition, variables, builtins) and iterations < maxIterations do
		-- Execute the loop body
		for _, statement in ipairs(body) do
			evaluator.executeStatement(statement, builtins, variables)
		end
		
		iterations = iterations + 1
	end
	
	if iterations >= maxIterations then
		warn("While loop exceeded maximum iterations (" .. maxIterations .. "), stopping to prevent infinite loop")
	end
end

-- Python-style truthiness evaluation
function ControlFlow.pythonTruthy(value)
	if value == nil or value == false then
		return false
	elseif value == 0 or value == "" then
		return false
	elseif type(value) == "table" and #value == 0 then
		return false
	else
		return true
	end
end

-- Parse comparison operators
function ControlFlow.parseComparison(expr, variables, builtins, evaluator)
	-- Handle different comparison operators
	local operators = {"==", "!=", "<=", ">=", "<", ">"}
	
	for _, op in ipairs(operators) do
		local pos = expr:find(op, 1, true)
		if pos then
			local left = expr:sub(1, pos - 1):match("^%s*(.-)%s*$")
			local right = expr:sub(pos + #op):match("^%s*(.-)%s*$")
			
			local leftVal = evaluator.evaluateExpression(left, variables, builtins)
			local rightVal = evaluator.evaluateExpression(right, variables, builtins)
			
			if op == "==" then
				return leftVal == rightVal
			elseif op == "!=" then
				return leftVal ~= rightVal
			elseif op == "<" then
				return leftVal < rightVal
			elseif op == ">" then
				return leftVal > rightVal
			elseif op == "<=" then
				return leftVal <= rightVal
			elseif op == ">=" then
				return leftVal >= rightVal
			end
		end
	end
	
	-- If no comparison operator found, evaluate as boolean
	return ControlFlow.pythonTruthy(evaluator.evaluateExpression(expr, variables, builtins))
end

return ControlFlow
