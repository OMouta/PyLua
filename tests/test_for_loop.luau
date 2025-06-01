local Python = require('../src/PyLua/python')

return function()
    Python.execute([[ 
        sum_i = 0
        for i in range(5):
            sum_i = sum_i + i
    ]])
    local sum_i = Python.getVariable('sum_i')
    if sum_i == 10 then
        return true, ''
    else
        return false, 'sum_i expected 10, got ' .. tostring(sum_i)
    end
end
