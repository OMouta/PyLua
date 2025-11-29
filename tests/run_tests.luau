--!strict
-- PyLua Test Runner

local TestFramework = require("./framework")
-- Aggregate run: disable per-suite summary; final summary printed manually
TestFramework.configure({ showPassed = false, color = true, showFailuresInline = false, autoSummaryPerFile = false })

require("./suites/test_api")
require("./suites/test_ast")
require("./suites/test_lexer")
require("./suites/test_parser")
require("./suites/test_objects_base")
require("./suites/test_objects_builtins")
require("./suites/test_objects_collections")
require("./suites/test_builtins")
require("./suites/test_classes")
require("./suites/test_bytecode")
require("./suites/test_vm")
require("./suites/test_functions")
require("./suites/test_generators")
require("./suites/test_control_flow")
require("./suites/test_exceptions")
require("./suites/test_interop")
require("./suites/test_modules")
require("./suites/test_modules_advanced")
require("./suites/test_pep451")

TestFramework.printSummary()
