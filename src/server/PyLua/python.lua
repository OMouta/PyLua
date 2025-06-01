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

-- Main execution function
function Python.execute(code)
	-- Split code into lines, preserving indentation
	local lines = {}
	for line in code:gmatch("[^\r\n]+") do
		table.insert(lines, line)
	end
	
	-- Parse all statements using the parser
	local statements = Parser.parseBlocks(lines)
	
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