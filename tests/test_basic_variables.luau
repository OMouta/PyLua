local Python = require('../src/PyLua/python')

return function()
    Python.execute([[ 
        message = "Python in Luau!"
        length = len(message)
    ]])
    local message = Python.getVariable('message')
    local length = Python.getVariable('length')
    if message ~= "Python in Luau!" then
        return false, 'message expected "Python in Luau!", got ' .. tostring(message)
    end
    if length ~= 15 then
        return false, 'length expected 15, got ' .. tostring(length)
    end
    return true, ''
end
