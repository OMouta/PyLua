--!strict
-- PyLua Test Framework
-- Simple testing utilities for PyLua development

local TestFramework = {}

-- Configuration (can be overridden via configure())
export type FrameworkConfig = {
	showPassed: boolean?, -- Print each passed assertion
	color: boolean?, -- Use ANSI colors
	showFailuresInline: boolean?, -- Show failure details immediately
	autoSummaryPerFile: boolean?, -- Automatically print summary after each suite (for single-file runs)
}

local config: FrameworkConfig = {
	showPassed = false,
	color = true,
	showFailuresInline = true,
	autoSummaryPerFile = true,
}

-- ANSI color helpers
local ANSI = {
	reset = "\27[0m",
	bold = "\27[1m",
	dim = "\27[2m",
	red = "\27[31m",
	green = "\27[32m",
	yellow = "\27[33m",
	cyan = "\27[36m",
}

local function colorize(code: string, text: string): string
	if not config.color then
		return text
	end
	return code .. text .. ANSI.reset
end

-- Test result tracking (assertion-level)
local totalAssertions = 0
local passedAssertions = 0
local failedAssertions = 0

-- Test case tracking
local totalTestCases = 0
local failedTestCases = 0

-- Failure records
type FailureRecord = { testName: string, message: string, trace: string }
local failures: { FailureRecord } = {}

-- Test suite definition
export type TestSuite = { name: string, tests: { TestCase } }

export type TestCase = {
	name: string,
	test: () -> (),
}

-- Assert functions
function TestFramework.assert(condition: boolean, message: string?)
	totalAssertions += 1
	if condition then
		passedAssertions += 1
		if config.showPassed then
			print(colorize(ANSI.green, "✓ " .. (message or "Assertion passed")))
		end
	else
		failedAssertions += 1
		local msg = message or "Assertion failed"
		if config.showFailuresInline then
			print(colorize(ANSI.red, "✗ " .. msg))
		end
		error(msg, 2)
	end
end

function TestFramework.assertEqual(actual: any, expected: any, message: string?)
	local msg = message or ("Expected " .. tostring(expected) .. " but got " .. tostring(actual))
	TestFramework.assert(actual == expected, msg)
end

function TestFramework.assertNotEqual(actual: any, expected: any, message: string?)
	local msg = message or ("Expected not " .. tostring(expected) .. " but got " .. tostring(actual))
	TestFramework.assert(actual ~= expected, msg)
end

function TestFramework.assertType(value: any, expectedType: string, message: string?)
	local actualType = type(value)
	local msg = message or ("Expected type " .. expectedType .. " but got " .. actualType)
	TestFramework.assert(actualType == expectedType, msg)
end

function TestFramework.assertTrue(condition: boolean, message: string?)
	local msg = message or "Expected true but got false"
	TestFramework.assert(condition == true, msg)
end

function TestFramework.assertFalse(condition: boolean, message: string?)
	local msg = message or "Expected false but got true"
	TestFramework.assert(condition == false, msg)
end

function TestFramework.assertError(func: () -> any, message: string?)
	totalAssertions += 1
	local success, err = pcall(func)
	if success then
		failedAssertions += 1
		local msg = message or "Expected error but none occurred"
		if config.showFailuresInline then
			print(colorize(ANSI.red, "✗ " .. msg))
		end
		error(msg, 2)
	else
		passedAssertions += 1
		if config.showPassed then
			print(colorize(ANSI.green, "✓ " .. (message or ("Expected error occurred: " .. tostring(err)))))
		end
	end
end

-- Allow external configuration
function TestFramework.configure(userConfig: FrameworkConfig)
	for k, v in pairs(userConfig) do
		(config :: any)[k] = v
	end
end

-- Run a test suite
function TestFramework.runSuite(suite: TestSuite)
	print("\n" .. colorize(ANSI.cyan, "Suite: " .. suite.name))
	local line = {}
	for _, testCase in ipairs(suite.tests) do
		totalTestCases += 1
		local testName = testCase.name
		local success, err = pcall(function()
			testCase.test()
		end)
		if success then
			table.insert(line, config.showPassed and colorize(ANSI.green, "·") or ".")
		else
			failedTestCases += 1
			table.insert(line, colorize(ANSI.red, "F"))
			table.insert(failures, { testName = testName, message = tostring(err), trace = debug.traceback() })
			if config.showFailuresInline then
				print(colorize(ANSI.red, "\nFailure: " .. testName .. " -> " .. tostring(err)))
			end
		end
	end
	print(table.concat(line))
	if config.autoSummaryPerFile then
		-- Print incremental summary without resetting counts so a single file run is informative
		TestFramework.printSummary()
	end
end

-- Print test results summary
function TestFramework.printSummary()
	if #failures > 0 then
		print("\n" .. colorize(ANSI.red, "Failures (" .. tostring(#failures) .. "):"))
		for i, f in ipairs(failures) do
			print(colorize(ANSI.red, tostring(i) .. ") " .. f.testName .. ": " .. f.message))
		end
	end
	print("\n" .. colorize(ANSI.bold, "=== Test Summary ==="))
	print(string.format("Test cases: %d total, %d failed", totalTestCases, failedTestCases))
	print(
		string.format(
			"Assertions : %d total, %d passed, %d failed",
			totalAssertions,
			passedAssertions,
			failedAssertions
		)
	)
	if failedTestCases == 0 and failedAssertions == 0 then
		print(colorize(ANSI.green, "✅ All tests passed"))
	else
		print(colorize(ANSI.red, "❌ Some tests failed"))
	end
	return failedTestCases == 0 and failedAssertions == 0
end

-- Reset test counters
function TestFramework.reset()
	totalAssertions = 0
	passedAssertions = 0
	failedAssertions = 0
	totalTestCases = 0
	failedTestCases = 0
	failures = {}
end

return TestFramework
