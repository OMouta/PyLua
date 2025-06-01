local Python = require('../src/PyLua/python')

return function()
    Python.execute([[ 
        numbers = range(1, 11)
        total = sum(numbers)
        minimum = min(numbers)
        maximum = max(numbers)
    ]])
    local total = Python.getVariable('total')
    local minimum = Python.getVariable('minimum')
    local maximum = Python.getVariable('maximum')
    if total ~= 55 then return false, 'total expected 55, got ' .. tostring(total) end
    if minimum ~= 1 then return false, 'minimum expected 1, got ' .. tostring(minimum) end
    if maximum ~= 10 then return false, 'maximum expected 10, got ' .. tostring(maximum) end
    return true, ''
end
