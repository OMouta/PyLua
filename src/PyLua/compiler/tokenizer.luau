-- PyLua Tokenizer
-- Converts Python code into tokens for bytecode compilation
-- Adapted from the original PyLua tokenizer for use with the bytecode system

local Tokenizer = {}

-- Simple tokenizer for Python code
function Tokenizer.tokenize(code)
	-- First, remove comments using table-based approach for better performance
	local cleanParts = {}
	local i = 1
	local partStart = 1
	
	while i <= #code do
		local char = code:sub(i, i)
		if char == "#" then
			-- Add the part before the comment
			if i > partStart then
				table.insert(cleanParts, code:sub(partStart, i - 1))
			end
			
			-- Skip everything until end of line
			while i <= #code and code:sub(i, i) ~= "\n" do
				i = i + 1
			end
			
			-- Add the newline if we found one
			if i <= #code and code:sub(i, i) == "\n" then
				table.insert(cleanParts, "\n")
				i = i + 1
			end
			partStart = i
		else
			i = i + 1
		end
	end
	
	-- Add remaining part
	if partStart <= #code then
		table.insert(cleanParts, code:sub(partStart, #code))
	end
	
	local cleanCode = table.concat(cleanParts)
	local tokens = {}
	local current = ""
	i = 1
	
	-- Helper function to add current token and a new token
	local function addTokens(newToken)
		if current ~= "" then
			table.insert(tokens, current)
			current = ""
		end
		table.insert(tokens, newToken)
	end
	
	while i <= #cleanCode do
		local char = cleanCode:sub(i, i)
		
		if char:match("%s") then
			-- Whitespace - finish current token if any
			if current ~= "" then
				table.insert(tokens, current)
				current = ""
			end
		elseif char == "(" then
			-- Opening parenthesis
			addTokens("(")
		elseif char == ")" then
			-- Closing parenthesis
			addTokens(")")
		elseif char == "[" then
			-- Opening bracket
			addTokens("[")
		elseif char == "]" then
			-- Closing bracket
			addTokens("]")
		elseif char == "{" then
			-- Opening brace
			addTokens("{")
		elseif char == "}" then
			-- Closing brace
			addTokens("}")
		elseif char == "," then
			-- Comma
			addTokens(",")
		elseif char == "=" then
			-- Assignment operator or equality
			if current ~= "" then
				table.insert(tokens, current)
				current = ""
			end
			-- Check for == operator
			if i + 1 <= #cleanCode and cleanCode:sub(i + 1, i + 1) == "=" then
				table.insert(tokens, "==")
				i = i + 1
			else
				table.insert(tokens, "=")
			end
		elseif char == "!" then
			-- Not equal operator
			if current ~= "" then
				table.insert(tokens, current)
				current = ""
			end
			-- Check for != operator
			if i + 1 <= #cleanCode and cleanCode:sub(i + 1, i + 1) == "=" then
				table.insert(tokens, "!=")
				i = i + 1
			else
				table.insert(tokens, "!")
			end
		elseif char == "<" then
			-- Less than or less than equal
			if current ~= "" then
				table.insert(tokens, current)
				current = ""
			end
			-- Check for <= operator
			if i + 1 <= #cleanCode and cleanCode:sub(i + 1, i + 1) == "=" then
				table.insert(tokens, "<=")
				i = i + 1
			else
				table.insert(tokens, "<")
			end
		elseif char == ">" then
			-- Greater than or greater than equal
			if current ~= "" then
				table.insert(tokens, current)
				current = ""
			end
			-- Check for >= operator
			if i + 1 <= #cleanCode and cleanCode:sub(i + 1, i + 1) == "=" then
				table.insert(tokens, ">=")
				i = i + 1
			else
				table.insert(tokens, ">")
			end
		elseif char == ":" then
			-- Colon for if statements and dict literals
			if current ~= "" then
				table.insert(tokens, current)
				current = ""
			end
			table.insert(tokens, ":")
		elseif char == "+" then
			-- Plus operator
			if current ~= "" then
				table.insert(tokens, current)
				current = ""
			end
			table.insert(tokens, "+")
		elseif char == "-" then
			-- Minus operator
			if current ~= "" then
				table.insert(tokens, current)
				current = ""
			end
			table.insert(tokens, "-")
		elseif char == "*" then
			-- Multiply operator
			if current ~= "" then
				table.insert(tokens, current)
				current = ""
			end
			table.insert(tokens, "*")
		elseif char == "/" then
			-- Divide operator
			if current ~= "" then
				table.insert(tokens, current)
				current = ""
			end
			table.insert(tokens, "/")
		elseif char == "%" then
			-- Modulus operator
			if current ~= "" then
				table.insert(tokens, current)
				current = ""
			end
			table.insert(tokens, "%")		elseif char == "." then
			-- Check if this is part of a decimal number
			if current ~= "" and current:match("^%d+$") and i + 1 <= #cleanCode and cleanCode:sub(i + 1, i + 1):match("%d") then
				-- This is a decimal point in a number, add it to current token
				current = current .. char
			else
				-- This is a dot operator for attribute access
				if current ~= "" then
					table.insert(tokens, current)
					current = ""
				end
				table.insert(tokens, ".")
			end
		elseif char == "\"" or char == "'" then
			-- String literal
			if current ~= "" then
				table.insert(tokens, current)
				current = ""
			end
			
			local quote = char
			local str = ""
			i = i + 1
			
			while i <= #cleanCode and cleanCode:sub(i, i) ~= quote do
				str = str .. cleanCode:sub(i, i)
				i = i + 1
			end
			
			table.insert(tokens, quote .. str .. quote)
		else
			current = current .. char
		end
		
		i = i + 1
	end
	
	if current ~= "" then
		table.insert(tokens, current)
	end
	
	return tokens
end

return Tokenizer
