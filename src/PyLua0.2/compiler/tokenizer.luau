-- PyLua 0.2 Tokenizer
-- Converts Python code into tokens for bytecode compilation
-- Adapted from the original PyLua tokenizer for use with the bytecode system

local Tokenizer = {}

-- Simple tokenizer for Python code
function Tokenizer.tokenize(code)
	-- First, remove comments
	local cleanCode = ""
	local i = 1
	while i <= #code do
		local char = code:sub(i, i)
		if char == "#" then
			-- Skip everything until end of line
			while i <= #code and code:sub(i, i) ~= "\n" do
				i = i + 1
			end
			-- Add the newline if we found one
			if i <= #code and code:sub(i, i) == "\n" then
				cleanCode = cleanCode .. "\n"
			end
		else
			cleanCode = cleanCode .. char
		end
		i = i + 1
	end
	
	local tokens = {}
	local current = ""
	i = 1
	
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
			table.insert(tokens, ")")
		elseif char == "[" then
			-- Opening bracket
			if current ~= "" then
				table.insert(tokens, current)
				current = ""
			end
			table.insert(tokens, "[")
		elseif char == "]" then
			-- Closing bracket
			if current ~= "" then
				table.insert(tokens, current)
				current = ""
			end
			table.insert(tokens, "]")
		elseif char == "{" then
			-- Opening brace
			if current ~= "" then
				table.insert(tokens, current)
				current = ""
			end
			table.insert(tokens, "{")
		elseif char == "}" then
			-- Closing brace
			if current ~= "" then
				table.insert(tokens, current)
				current = ""
			end
			table.insert(tokens, "}")
		elseif char == "," then
			-- Comma
			if current ~= "" then
				table.insert(tokens, current)
				current = ""
			end
			table.insert(tokens, ",")
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
