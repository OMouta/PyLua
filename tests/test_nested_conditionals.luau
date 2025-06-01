local Python = require('../src/PyLua/python')

return function()
    Python.execute([[ 
        x = 10
        if x > 0:
            is_positive = True
            if x % 2 == 0:
                is_even = True
            else:
                is_even = False
        else:
            is_positive = False
            is_even = None
    ]])
    local is_positive = Python.getVariable('is_positive')
    local is_even = Python.getVariable('is_even')
    if is_positive ~= true then return false, 'is_positive expected true, got ' .. tostring(is_positive) end
    if is_even ~= true then return false, 'is_even expected true, got ' .. tostring(is_even) end
    return true, ''
end
