-- PyLua Control Flow
-- Handles conditional statements and loops

local ControlFlow = {}

-- Execute a statement (handles both regular statements and nested if statements)
local function executeStatement(statement, evaluator, builtins, variables)
	if statement.type == "complete_if_statement" then
		-- This is a nested if statement, execute it recursively
		if #statement.elifChain > 0 then
			ControlFlow.executeIfChain(statement.condition, statement.ifBlock, statement.elifChain, statement.elseBlock, evaluator, builtins, variables)
		else
			ControlFlow.executeIf(statement.condition, statement.ifBlock, statement.elseBlock, evaluator, builtins, variables)
		end
	else
		-- Regular statement
		evaluator.executeStatement(statement, builtins, variables)
	end
end

-- Execute an if statement
function ControlFlow.executeIf(condition, ifBody, elseBody, evaluator, builtins, variables)
	-- Evaluate the condition
	local isTrue = evaluator.evaluateCondition(condition, variables, builtins)
	
	if isTrue then
		-- Execute if body
		for _, statement in ipairs(ifBody) do
			executeStatement(statement, evaluator, builtins, variables)
		end
	elseif elseBody then
		-- Execute else body
		for _, statement in ipairs(elseBody) do
			executeStatement(statement, evaluator, builtins, variables)
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
			executeStatement(statement, evaluator, builtins, variables)
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
					executeStatement(statement, evaluator, builtins, variables)
				end
				return
			end
		end
	end
	
	-- If no conditions were true, execute else body
	if elseBody then
		for _, statement in ipairs(elseBody) do
			executeStatement(statement, evaluator, builtins, variables)
		end
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
