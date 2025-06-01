local tests = {
    {name = "test_basic_variables", fn = require("./test_basic_variables")},
    {name = "test_math_operations", fn = require("./test_math_operations")},
    {name = "test_while_loop", fn = require("./test_while_loop")},
    {name = "test_for_loop", fn = require("./test_for_loop")},
    {name = "test_list_literals", fn = require("./test_list_literals")},
    {name = "test_type_conversions", fn = require("./test_type_conversions")},
    {name = "test_power_function", fn = require("./test_power_function")},
    {name = "test_string_comparison", fn = require("./test_string_comparison")},
    {name = "test_nested_conditionals", fn = require("./test_nested_conditionals")}
}

local passed = 0
local failed = 0

print("=== PyLua Automated Test Runner ===")
for _, test in ipairs(tests) do
    local ok = false
    local fail_reason = ''
    local success, result = pcall(function()
        local r = {test.fn()}
        if #r < 2 then table.insert(r, '') end
        return r
    end)
    local test_passed, reason = false, ''
    if success and type(result) == 'table' then
        test_passed, reason = result[1], result[2]
    end
    if success and test_passed then
        ok = true
    elseif success then
        fail_reason = tostring(reason)
        if not fail_reason or fail_reason == '' then
            fail_reason = '(no reason provided)'
        end
    else
        fail_reason = tostring(result or '')
    end
    if ok then
        print("[PASS]", test.name)
        passed = passed + 1
    else
        print("[FAIL]", test.name, fail_reason)
        failed = failed + 1
    end
end
print(string.format("\nSummary: %d passed, %d failed, %d total", passed, failed, #tests))
return passed == #tests
