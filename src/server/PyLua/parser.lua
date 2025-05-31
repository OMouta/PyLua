-- PyLua Parser
-- Parses tokens into executable statements

local Parser = {}

-- Parse a function call from tokens
function Parser.parseFunctionCall(tokens, startIndex)
	local funcName = tokens[startIndex]
	local args = {}
	
	if startIndex + 1 <= #tokens and tokens[startIndex + 1] == "(" then
		local i = startIndex + 2
		local current_arg = ""
		local paren_count = 1
		
		while i <= #tokens and paren_count > 0 do
			local token = tokens[i]
			
			if token == "(" then
				paren_count = paren_count + 1
				current_arg = current_arg .. token
			elseif token == ")" then
				paren_count = paren_count - 1
				if paren_count == 0 then
					if current_arg ~= "" then
						table.insert(args, current_arg)
					end
				else
					current_arg = current_arg .. token
				end
			elseif token == "," and paren_count == 1 then
				if current_arg ~= "" then
					table.insert(args, current_arg)
					current_arg = ""
				end
			else
				current_arg = current_arg .. token
			end
			
			i = i + 1
		end
		
		return funcName, args, i
	end
	
	return funcName, {}, startIndex + 1
end

-- Parse a statement and determine its type
function Parser.parseStatement(tokens)
	if #tokens == 0 then
		return nil
	end
		-- Check for if statement
	if tokens[1] == "if" then
		return Parser.parseIfStatement(tokens)
	end
	
	-- Check for elif statement
	if tokens[1] == "elif" then
		return Parser.parseElifStatement(tokens)
	end
	
	-- Check for else statement
	if tokens[1] == "else" then
		return {
			type = "else",
			tokens = tokens
		}
	end
	
	-- Check for assignment (variable = value)
	for i, token in ipairs(tokens) do
		if token == "=" and i > 1 then -- Make sure = is not the first token
			local varName = tokens[1]
			local valueTokens = {}
			for j = i + 1, #tokens do
				table.insert(valueTokens, tokens[j])
			end
			
			-- Join tokens with appropriate spacing
			local value = ""
			for k, vToken in ipairs(valueTokens) do
				if k > 1 then
					-- Add space between most tokens, except for parentheses and operators
					local prevToken = valueTokens[k-1]
					local needsSpace = not (vToken == "(" or vToken == ")" or prevToken == "(" or 
					                       vToken == "," or prevToken == "," or
					                       (vToken:match("[%+%-%*/]") and #vToken == 1) or
					                       (prevToken:match("[%+%-%*/]") and #prevToken == 1))
					if needsSpace then
						value = value .. " "
					end
				end
				value = value .. vToken
			end
			
			return {
				type = "assignment",
				variable = varName,
				value = value
			}
		end
	end
	
	-- Check for function calls
	local funcName, args, nextIndex = Parser.parseFunctionCall(tokens, 1)
	
	return {
		type = "function_call",
		name = funcName,
		arguments = args
	}
end

-- Parse a mathematical expression
function Parser.parseExpression(tokens)
	-- Simple expression parser for basic math operations
	local result = {}
	
	for _, token in ipairs(tokens) do
		if token == "+" or token == "-" or token == "*" or token == "/" then
			table.insert(result, {type = "operator", value = token})
		elseif tonumber(token) then
			table.insert(result, {type = "number", value = tonumber(token)})
		else
			table.insert(result, {type = "identifier", value = token})
		end
	end
	
	return result
end

-- Parse an if statement
function Parser.parseIfStatement(tokens)
	-- Find the condition (between 'if' and ':')
	local conditionTokens = {}
	local colonIndex = nil
	
	for i = 2, #tokens do
		if tokens[i] == ":" then
			colonIndex = i
			break
		else
			table.insert(conditionTokens, tokens[i])
		end
	end
	
	if not colonIndex then
		error("Invalid if statement: missing colon")
	end
	
	-- Join condition tokens
	local condition = table.concat(conditionTokens, " ")
	
	return {
		type = "if_statement",
		condition = condition
	}
end

-- Parse an elif statement
function Parser.parseElifStatement(tokens)
	-- Find the condition (between 'elif' and ':')
	local conditionTokens = {}
	local colonIndex = nil
	
	for i = 2, #tokens do
		if tokens[i] == ":" then
			colonIndex = i
			break
		else
			table.insert(conditionTokens, tokens[i])
		end
	end
	
	if not colonIndex then
		error("Invalid elif statement: missing colon")
	end
	
	-- Join condition tokens
	local condition = table.concat(conditionTokens, " ")
	
	return {
		type = "elif_statement",
		condition = condition
	}
end

return Parser
