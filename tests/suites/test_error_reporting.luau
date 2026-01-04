--!nocheck
local TestFramework = require("../framework")
local Lexer = require("../../src/PyLua/lexer")
local Parser = require("../../src/PyLua/parser")

local errorTests = {
	name = "Error Reporting Tests",
	tests = {
		{
			name = "Parse Error with Line Number (Indentation)",
			test = function()
				local code = "x = 1\nif x:\n    y = 2\n  z = 3" -- Indentation error at line 4
				local tokens = Lexer.tokenize(code)
				
                local success, err = pcall(function()
                    Parser.parse(tokens)
                end)

                TestFramework.assertFalse(success, "Should have raised an error")
                local errStr = tostring(err)
                -- print("Error message: " .. errStr)
                
                local hasLine = string.find(errStr, "line 4")
                TestFramework.assert(hasLine ~= nil, "Error message should contain 'line 4'. Got: " .. errStr)
			end,
		},
        {
            name = "Unexpected Token Error with Line Number",
            test = function()
                local code = "x = (\n    1 +\n    * 2\n)" 
                -- Line 1: x = (
                -- Line 2:     1 +
                -- Line 3:     * 2
                -- Error should be at line 3 (STAR unexpected)
                
                local tokens = Lexer.tokenize(code)
                local success, err = pcall(function()
                    Parser.parse(tokens)
                end)
                
                TestFramework.assertFalse(success, "Should have raised an error")
                local errStr = tostring(err)
                -- print("Error message: " .. errStr)
                
                local hasLine = string.find(errStr, "line 3")
                TestFramework.assert(hasLine ~= nil, "Error message should contain 'line 3'. Got: " .. errStr)
            end
        }
	},
}

TestFramework.runSuite(errorTests)

return errorTests
