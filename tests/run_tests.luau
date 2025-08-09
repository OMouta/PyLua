--!strict
-- PyLua Test Runner

local TestFramework = require('./framework')
-- Aggregate run: disable per-suite summary; final summary printed manually
TestFramework.configure({ showPassed = false, color = true, showFailuresInline = false, autoSummaryPerFile = false })

require('./test_api')
require('./test_ast')
require('./test_lexer')
require('./test_parser')

TestFramework.printSummary()

