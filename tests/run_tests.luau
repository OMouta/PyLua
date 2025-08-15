--!strict
-- PyLua Test Runner

local TestFramework = require("./framework")
-- Aggregate run: disable per-suite summary; final summary printed manually
TestFramework.configure({ showPassed = false, color = true, showFailuresInline = false, autoSummaryPerFile = false })

require("./test_api")
require("./test_ast")
require("./test_lexer")
require("./test_parser")
require("./test_objects_base")
require("./test_objects_builtins")
require("./test_objects_collections")
require("./test_bytecode")

TestFramework.printSummary()
