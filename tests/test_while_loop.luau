local Python = require('../src/PyLua/python')

return function()
    Python.execute([[ 
        count = 0
        while count < 5:
            count = count + 1
    ]])
    local count = Python.getVariable('count')
    if count == 5 then
        return true, ''
    else
        return false, 'count expected 5, got ' .. tostring(count)
    end
end
