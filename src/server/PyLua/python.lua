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

-- Execute a single Python statement (no longer used directly, but kept for compatibility)
local function _executeStatement(statement)
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

-- Forward declarations to handle mutual recursion
local parseStatementList
local parseIfStatement

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
			local tokens = Tokenizer.tokenize(trimmed)
			local parsed = Parser.parseStatement(tokens)
			
			if parsed and parsed.type == "if_statement" then
				-- This is an if statement, collect its nested structure recursively
				local ifResult, nextIndex = parseIfStatement(lines, i, indent)
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

-- Parse an if statement and its complete if/elif/else chain
parseIfStatement = function(lines, startIndex, baseIndent)
	local line = lines[startIndex]
	local trimmed = line:match("^%s*(.-)%s*$")
	local tokens = Tokenizer.tokenize(trimmed)
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
			local elifTokens = Tokenizer.tokenize(currentTrimmed)
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

-- Parse indented block structure
local function parseBlocks(lines)
	local statements, _ = parseStatementList(lines, 1, nil)
	
	-- Execute all statements
	for _, statement in ipairs(statements) do
		if statement.type == "complete_if_statement" then
			-- Execute the complete if/elif/else chain
			if #statement.elifChain > 0 then
				ControlFlow.executeIfChain(statement.condition, statement.ifBlock, statement.elifChain, statement.elseBlock, Evaluator, Builtins.getAll(), Variables)
			else
				ControlFlow.executeIf(statement.condition, statement.ifBlock, statement.elseBlock, Evaluator, Builtins.getAll(), Variables)
			end
		else
			-- Execute regular statement
			Evaluator.executeStatement(statement, Builtins.getAll(), Variables)
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