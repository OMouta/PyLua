-- PyLua Tokenizer
-- Converts Python code into tokens for parsing

local Tokenizer = {}

-- Simple tokenizer for Python code
function Tokenizer.tokenize(code)
	local tokens = {}
	local current = ""
	local i = 1
	
	while i <= #code do
		local char = code:sub(i, i)
		
		if char:match("%s") then
			-- Whitespace - finish current token if any
			if current ~= "" then
				table.insert(tokens, current)
				current = ""
			end
		elseif char == "(" then
			-- Opening parenthesis
			if current ~= "" then
				table.insert(tokens, current)
				current = ""
			end
			table.insert(tokens, "(")
		elseif char == ")" then
			-- Closing parenthesis
			if current ~= "" then
				table.insert(tokens, current)
				current = ""
			end
			table.insert(tokens, ")")		elseif char == "," then
			-- Comma
			if current ~= "" then
				table.insert(tokens, current)
				current = ""
			end
			table.insert(tokens, ",")		elseif char == "=" then
			-- Assignment operator or equality
			if current ~= "" then
				table.insert(tokens, current)
				current = ""
			end
			-- Check for == operator
			if i + 1 <= #code and code:sub(i + 1, i + 1) == "=" then
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
			if i + 1 <= #code and code:sub(i + 1, i + 1) == "=" then
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
			if i + 1 <= #code and code:sub(i + 1, i + 1) == "=" then
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
			if i + 1 <= #code and code:sub(i + 1, i + 1) == "=" then
				table.insert(tokens, ">=")
				i = i + 1
			else
				table.insert(tokens, ">")
			end
		elseif char == ":" then
			-- Colon for if statements
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
		elseif char == "\"" or char == "'" then
			-- String literal
			if current ~= "" then
				table.insert(tokens, current)
				current = ""
			end
			
			local quote = char
			local str = ""
			i = i + 1
			
			while i <= #code and code:sub(i, i) ~= quote do
				str = str .. code:sub(i, i)
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
