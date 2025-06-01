local Python = require('../src/PyLua/python')

return function()
    Python.execute([[ 
        name = "PyLua"
        if name == "Python":
            is_python = True
        else:
            is_python = False
        
        if name == "Lua":
            is_lua = True
        else:
            is_lua = False
    ]])
    local is_python = Python.getVariable('is_python')
    local is_lua = Python.getVariable('is_lua')
    if is_python == false and is_lua == false then
        return true, ''
    else
        return false, 'is_python: ' .. tostring(is_python) .. ', is_lua: ' .. tostring(is_lua)
    end
end
