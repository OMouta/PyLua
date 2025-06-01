local Python = require('../src/PyLua/python')

return function()
    Python.execute([[ 
        my_list = [1, 2, 3, 4, 5]
        my_list_len = len(my_list)
    ]])
    local my_list_len = Python.getVariable('my_list_len')
    if my_list_len == 5 then
        return true, ''
    else
        return false, 'my_list_len expected 5, got ' .. tostring(my_list_len)
    end
end
