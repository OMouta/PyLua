-- PyLua Evaluator
-- Evaluates Python expressions and executes statements

local Evaluator = {}

-- Evaluate a Python expression (enhanced implementation)
function Evaluator.evaluateExpression(expr, variables, builtins)
	-- Remove leading/trailing whitespace
	expr = expr:match("^%s*(.-)%s*$")
	
	-- Handle string literals
	if (expr:sub(1, 1) == "\"" and expr:sub(-1, -1) == "\"") or 
	   (expr:sub(1, 1) == "'" and expr:sub(-1, -1) == "'") then
		return expr:sub(2, -2) -- Remove quotes
	end
	
	-- Handle numbers
	local num = tonumber(expr)
	if num then
		return num
	end
	
	-- Handle function calls (like len(text), type(x), etc.)
	if expr:find("%(") and expr:find("%)") then
		return Evaluator.evaluateFunctionCall(expr, variables, builtins)
	end
	
	-- Handle variables
	if variables and variables.exists(expr) then
		return variables.get(expr)
	end
	
	-- Handle simple mathematical expressions
	if expr:find("[%+%-%*/]") then
		return Evaluator.evaluateMathExpression(expr, variables, builtins)
	end
	
	-- For now, return the expression as-is if we can't evaluate it
	return expr
end

-- Evaluate a function call within an expression
function Evaluator.evaluateFunctionCall(expr, variables, builtins)
	-- Extract function name and arguments
	local funcName = expr:match("([%w_]+)%(")
	if not funcName then
		return expr -- Not a valid function call
	end
	
	-- Extract arguments from parentheses
	local argsStr = expr:match("%((.-)%)")
	if not argsStr then
		return expr
	end
	
	-- Check if it's a built-in function
	if builtins and builtins[funcName] then
		-- Parse multiple arguments separated by commas
		local args = {}
		if argsStr ~= "" then
			-- Split by commas but handle nested function calls
			local currentArg = ""
			local parenCount = 0
			
			for i = 1, #argsStr do
				local char = argsStr:sub(i, i)
				if char == "(" then
					parenCount = parenCount + 1
					currentArg = currentArg .. char
				elseif char == ")" then
					parenCount = parenCount - 1
					currentArg = currentArg .. char
				elseif char == "," and parenCount == 0 then
					table.insert(args, Evaluator.evaluateExpression(currentArg:match("^%s*(.-)%s*$"), variables, builtins))
					currentArg = ""
				else
					currentArg = currentArg .. char
				end
			end
			
			-- Add the last argument
			if currentArg ~= "" then
				table.insert(args, Evaluator.evaluateExpression(currentArg:match("^%s*(.-)%s*$"), variables, builtins))
			end
		end
		
		-- Call the built-in function with all arguments
		return builtins[funcName](table.unpack(args))
	end
	
	return expr -- Unknown function
end

-- Evaluate a mathematical expression
function Evaluator.evaluateMathExpression(expr, variables, builtins)
	-- Remove all spaces for easier parsing
	local cleanExpr = expr:gsub("%s+", "")
	
	-- Replace variables with their values
	if variables then
		for varName, value in pairs(variables.getAll()) do
			-- Only replace whole words (not parts of other identifiers)
			cleanExpr = cleanExpr:gsub("%f[%w_]" .. varName .. "%f[^%w_]", tostring(value))
		end
	end
	
	-- Handle function calls within the expression
	while cleanExpr:find("%w+%(") do
		local funcCall = cleanExpr:match("(%w+%([^%)]*%))")
		if funcCall then
			local result = Evaluator.evaluateFunctionCall(funcCall, variables, builtins)
			cleanExpr = cleanExpr:gsub(funcCall:gsub("([%(%)%+%-%*%/])", "%%%1"), tostring(result))
		else
			break
		end
	end
	
	-- Now evaluate the mathematical expression safely
	return Evaluator.safeMathEval(cleanExpr)
end

-- Safely evaluate a mathematical expression without using load()
function Evaluator.safeMathEval(expr)
	-- Simple recursive descent parser for basic math operations
	-- This is a basic implementation - handles +, -, *, / with proper precedence
	
	-- Remove spaces
	expr = expr:gsub("%s+", "")
	
	-- Handle simple cases first
	local num = tonumber(expr)
	if num then
		return num
	end
	
	-- Find operators in order of precedence (lowest to highest)
	-- Addition and subtraction (lowest precedence)
	for i = #expr, 1, -1 do
		local char = expr:sub(i, i)
		if char == "+" or char == "-" then
			-- Make sure it's not at the beginning (negative number)
			if i > 1 then
				local left = expr:sub(1, i - 1)
				local right = expr:sub(i + 1)
				local leftVal = Evaluator.safeMathEval(left)
				local rightVal = Evaluator.safeMathEval(right)
				
				if char == "+" then
					return leftVal + rightVal
				else
					return leftVal - rightVal
				end
			end
		end
	end
	
	-- Multiplication and division (higher precedence)
	for i = #expr, 1, -1 do
		local char = expr:sub(i, i)
		if char == "*" or char == "/" then
			local left = expr:sub(1, i - 1)
			local right = expr:sub(i + 1)
			local leftVal = Evaluator.safeMathEval(left)
			local rightVal = Evaluator.safeMathEval(right)
			
			if char == "*" then
				return leftVal * rightVal
			else
				if rightVal ~= 0 then
					return leftVal / rightVal
				else
					warn("Division by zero")
					return 0
				end
			end
		end
	end
	
	-- If we get here, we couldn't parse the expression
	warn("Could not evaluate expression: " .. expr)
	return 0
end

-- Evaluate a condition (comparison expression)
function Evaluator.evaluateCondition(condition, variables, builtins)
	-- Handle different comparison operators
	local operators = {"==", "!=", "<=", ">=", "<", ">"}
	
	for _, op in ipairs(operators) do
		local pos = condition:find(op, 1, true)
		if pos then
			local left = condition:sub(1, pos - 1):match("^%s*(.-)%s*$")
			local right = condition:sub(pos + #op):match("^%s*(.-)%s*$")
			
			local leftVal = Evaluator.evaluateExpression(left, variables, builtins)
			local rightVal = Evaluator.evaluateExpression(right, variables, builtins)
			
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
	
	-- If no comparison operator found, evaluate as boolean (Python-style truthiness)
	local value = Evaluator.evaluateExpression(condition, variables, builtins)
	return Evaluator.pythonTruthy(value)
end

-- Python-style truthiness evaluation
function Evaluator.pythonTruthy(value)
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

-- Execute a parsed statement
function Evaluator.executeStatement(statement, builtins, variables)
	if not statement then
		return
	end
	
	if statement.type == "assignment" then
		local value = Evaluator.evaluateExpression(statement.value, variables, builtins)
		variables.set(statement.variable, value)
		
	elseif statement.type == "function_call" then
		local funcName = statement.name
		local args = statement.arguments
		
		if builtins[funcName] then
			-- Evaluate arguments
			local evaluatedArgs = {}
			for _, arg in ipairs(args) do
				table.insert(evaluatedArgs, Evaluator.evaluateExpression(arg, variables, builtins))
			end
			
			-- Call the built-in function
			builtins[funcName](table.unpack(evaluatedArgs))
		else
			warn("Unknown function: " .. funcName)
		end
		
	elseif statement.type == "if_statement" then
		-- Return the statement for the main interpreter to handle
		-- (since if statements require looking ahead for indented blocks)
		return statement
		
	else
		warn("Unknown statement type: " .. tostring(statement.type))
	end
end

return Evaluator
