-- PyLua: A Python Interpreter in Luau
-- Main module for the Python interpreter

local Python = {}

-- Import modular components
local Tokenizer = require('./tokenizer')
local Parser = require('./parser')
local Evaluator = require('./evaluator')
local Builtins = require('./builtins')
local Variables = require('./variables')
local ControlFlow = require('./controlflow')

-- Execute a single Python statement
local function executeStatement(statement)
	local tokens = Tokenizer.tokenize(statement)
	local parsed = Parser.parseStatement(tokens)
	local result = Evaluator.executeStatement(parsed, Builtins.getAll(), Variables)
	
	-- If it's an if statement, return it for block processing
	if parsed and parsed.type == "if_statement" then
		return parsed
	end
	
	return result
end

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

-- Parse indented block structure
local function parseBlocks(lines)
	local blocks = {}
	local i = 1
	
	while i <= #lines do
		local line = lines[i]
		local trimmed = line:match("^%s*(.-)%s*$")
		
		if trimmed ~= "" then
			local tokens = Tokenizer.tokenize(trimmed)
			local parsed = Parser.parseStatement(tokens)
					if parsed and parsed.type == "if_statement" then
				-- This is an if statement, collect its block and any elif/else blocks
				local ifBlock = {}
				local elifChain = {}
				local elseBlock = nil
				local baseIndent = getIndentLevel(line)
				i = i + 1
				
				-- Collect if block (indented lines)
				while i <= #lines do
					local blockLine = lines[i]
					local blockTrimmed = blockLine:match("^%s*(.-)%s*$")
					local blockIndent = getIndentLevel(blockLine)
					
					if blockTrimmed == "" then
						i = i + 1 -- Skip empty lines
					elseif blockIndent > baseIndent then
						-- This line belongs to the if block
						local blockTokens = Tokenizer.tokenize(blockTrimmed)
						local blockParsed = Parser.parseStatement(blockTokens)
						table.insert(ifBlock, blockParsed)
						i = i + 1
					elseif blockTrimmed:sub(1, 4) == "elif" and blockIndent == baseIndent then
						-- Found elif statement
						local elifTokens = Tokenizer.tokenize(blockTrimmed)
						local elifParsed = Parser.parseStatement(elifTokens)
						local elifBody = {}
						i = i + 1
						
						-- Collect elif block
						while i <= #lines do
							local elifLine = lines[i]
							local elifTrimmed = elifLine:match("^%s*(.-)%s*$")
							local elifIndent = getIndentLevel(elifLine)
							
							if elifTrimmed == "" then
								i = i + 1
							elseif elifIndent > baseIndent then
								local elifLineTokens = Tokenizer.tokenize(elifTrimmed)
								local elifLineParsed = Parser.parseStatement(elifLineTokens)
								table.insert(elifBody, elifLineParsed)
								i = i + 1
							else
								-- Next elif, else, or end of block
								break
							end
						end
						
						table.insert(elifChain, {
							condition = elifParsed.condition,
							body = elifBody
						})
					elseif blockTrimmed:sub(1, 4) == "else" and blockIndent == baseIndent then
						-- Found else statement
						i = i + 1
						elseBlock = {}
						
						-- Collect else block
						while i <= #lines do
							local elseLine = lines[i]
							local elseTrimmed = elseLine:match("^%s*(.-)%s*$")
							local elseIndent = getIndentLevel(elseLine)
							
							if elseTrimmed == "" then
								i = i + 1
							elseif elseIndent > baseIndent then
								local elseTokens = Tokenizer.tokenize(elseTrimmed)
								local elseParsed = Parser.parseStatement(elseTokens)
								table.insert(elseBlock, elseParsed)
								i = i + 1
							else
								break
							end
						end
						break
					else
						-- End of if block
						break
					end
				end
				
				-- Execute the if/elif/else chain
				if #elifChain > 0 then
					ControlFlow.executeIfChain(parsed.condition, ifBlock, elifChain, elseBlock, Evaluator, Builtins.getAll(), Variables)
				else
					ControlFlow.executeIf(parsed.condition, ifBlock, elseBlock, Evaluator, Builtins.getAll(), Variables)
				end
			elseif parsed and parsed.type == "for_statement" then
				-- This is a for loop, collect its body
				local forBody = {}
				local baseIndent = getIndentLevel(line)
				i = i + 1
				
				-- Collect for loop body (indented lines)
				while i <= #lines do
					local blockLine = lines[i]
					local blockTrimmed = blockLine:match("^%s*(.-)%s*$")
					local blockIndent = getIndentLevel(blockLine)
					
					if blockTrimmed == "" then
						i = i + 1 -- Skip empty lines
					elseif blockIndent > baseIndent then
						-- This line belongs to the for loop body
						local blockTokens = Tokenizer.tokenize(blockTrimmed)
						local blockParsed = Parser.parseStatement(blockTokens)
						table.insert(forBody, blockParsed)
						i = i + 1
					else
						-- End of for loop body
						break
					end
				end
				
				-- Execute the for loop
				ControlFlow.executeFor(parsed.variable, parsed.iterable, forBody, Evaluator, Builtins.getAll(), Variables)
			elseif parsed and parsed.type == "while_statement" then
				-- This is a while loop, collect its body
				local whileBody = {}
				local baseIndent = getIndentLevel(line)
				i = i + 1
				
				-- Collect while loop body (indented lines)
				while i <= #lines do
					local blockLine = lines[i]
					local blockTrimmed = blockLine:match("^%s*(.-)%s*$")
					local blockIndent = getIndentLevel(blockLine)
					
					if blockTrimmed == "" then
						i = i + 1 -- Skip empty lines
					elseif blockIndent > baseIndent then
						-- This line belongs to the while loop body
						local blockTokens = Tokenizer.tokenize(blockTrimmed)
						local blockParsed = Parser.parseStatement(blockTokens)
						table.insert(whileBody, blockParsed)
						i = i + 1
					else
						-- End of while loop body
						break
					end
				end
				
				-- Execute the while loop
				ControlFlow.executeWhile(parsed.condition, whileBody, Evaluator, Builtins.getAll(), Variables)
			else
				-- Regular statement
				executeStatement(trimmed)
				i = i + 1
			end
		else
			i = i + 1
		end
	end
end

-- Main execution function
function Python.execute(code)
	-- Split code into lines, preserving indentation
	local lines = {}
	for line in code:gmatch("[^\r\n]+") do
		table.insert(lines, line)
	end
	
	-- Parse and execute blocks
	parseBlocks(lines)
end

-- Add a built-in function to the interpreter
function Python.addBuiltin(name, func)
	Builtins.add(name, func)
end

-- Get all available built-ins
function Python.getBuiltins()
	return Builtins.getAll()
end

-- Get access to individual modules for advanced usage
function Python.getModules()
	return {
		tokenizer = Tokenizer,
		parser = Parser,
		evaluator = Evaluator,
		builtins = Builtins,
		variables = Variables,
		controlflow = ControlFlow
	}
end

-- Get variable value
function Python.getVariable(name)
	return Variables.get(name)
end

-- Set variable value
function Python.setVariable(name, value)
	Variables.set(name, value)
end

-- Clear all variables
function Python.clearVariables()
	Variables.clear()
end

return Python