-- PyLua Parser
-- Parses tokens into executable statements

local Parser = {}

-- Get indentation level of a line
local function getIndentLevel(line)
	local indent = 0
	for i = 1, #line do
		local char = line:sub(i, i)
		if char == " " then
			indent = indent + 1
		elseif char == "\t" then
			indent = indent + 4 -- Treat tab as 4 spaces
		else
			break
		end
	end
	return indent
end

-- Forward declarations to handle mutual recursion
local parseStatementList
local parseIfStatementWithBlocks

-- Parse a list of statement lines recursively to handle nested structures
parseStatementList = function(lines, startIndex, maxIndent)
	local statements = {}
	local i = startIndex or 1
	
	while i <= #lines do
		local line = lines[i]
		local trimmed = line:match("^%s*(.-)%s*$")
		local indent = getIndentLevel(line)
		
		-- Skip empty lines
		if trimmed == "" then
			i = i + 1
		-- Stop if we hit a line with less indentation than expected
		elseif maxIndent and indent < maxIndent then
			break
		-- Stop if we hit elif/else at the same level (these belong to the parent if)
		elseif maxIndent and indent == maxIndent and (trimmed:sub(1, 4) == "elif" or trimmed:sub(1, 4) == "else") then
			break
		else
			local tokens = require('./tokenizer').tokenize(trimmed)
			local parsed = Parser.parseStatement(tokens)
			
			if parsed and parsed.type == "if_statement" then
				-- This is an if statement, collect its nested structure recursively
				local ifResult, nextIndex = parseIfStatementWithBlocks(lines, i, indent)
				table.insert(statements, ifResult)
				i = nextIndex
			else
				-- Regular statement
				table.insert(statements, parsed)
				i = i + 1
			end
		end
	end
	
	return statements, i
end

-- Parse an if statement and its complete if/elif/else chain with nested blocks
parseIfStatementWithBlocks = function(lines, startIndex, baseIndent)
	local line = lines[startIndex]
	local trimmed = line:match("^%s*(.-)%s*$")
	local tokens = require('./tokenizer').tokenize(trimmed)
	local parsed = Parser.parseStatement(tokens)
	
	local ifBlock = {}
	local elifChain = {}
	local elseBlock = nil
	local i = startIndex + 1
	
	-- Parse if block
	ifBlock, i = parseStatementList(lines, i, baseIndent + 1)
	
	-- Parse elif and else blocks
	while i <= #lines do
		local currentLine = lines[i]
		local currentTrimmed = currentLine:match("^%s*(.-)%s*$")
		local currentIndent = getIndentLevel(currentLine)
		
		if currentTrimmed == "" then
			i = i + 1
		elseif currentIndent == baseIndent and currentTrimmed:sub(1, 4) == "elif" then
			-- Parse elif statement
			local elifTokens = require('./tokenizer').tokenize(currentTrimmed)
			local elifParsed = Parser.parseStatement(elifTokens)
			i = i + 1
			
			local elifBody, nextIndex = parseStatementList(lines, i, baseIndent + 1)
			table.insert(elifChain, {
				condition = elifParsed.condition,
				body = elifBody
			})
			i = nextIndex
		elseif currentIndent == baseIndent and currentTrimmed:sub(1, 4) == "else" then
			-- Parse else statement
			i = i + 1
			elseBlock, i = parseStatementList(lines, i, baseIndent + 1)
			break
		else
			-- End of if/elif/else chain
			break
		end
	end
	
	-- Create a complete if statement structure
	local ifStatement = {
		type = "complete_if_statement",
		condition = parsed.condition,
		ifBlock = ifBlock,
		elifChain = elifChain,
		elseBlock = elseBlock
	}
	
	return ifStatement, i
end

-- Parse a complete code block with nested structures
function Parser.parseBlocks(lines)
	local statements, _ = parseStatementList(lines, 1, nil)
	return statements
end

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
				-- Add space between tokens except for certain cases
				if current_arg ~= "" and not (token:match("^[%(%)]$") or current_arg:match("[%(%)]$")) then
					current_arg = current_arg .. " "
				end
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
	local funcName, args, _nextIndex = Parser.parseFunctionCall(tokens, 1)
	
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
