local Python = require('../src/PyLua/python')

return function()
    Python.execute([[
        base = 2
        exponent = 8
        result = pow(base, exponent)
    ]])
    local result = Python.getVariable('result')
    if result == 256 then
        return true, ''
    else
        return false, 'result expected 256, got ' .. tostring(result)
    end
end
