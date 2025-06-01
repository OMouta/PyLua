local Python = require('../src/PyLua/python')

return function()
    Python.execute([[ 
        float_num = float("3.14")
        int_num = int(float_num)
        bool_val = bool(1)
    ]])
    local float_num = Python.getVariable('float_num')
    local int_num = Python.getVariable('int_num')
    local bool_val = Python.getVariable('bool_val')
    if math.abs(float_num - 3.14) > 0.001 then return false, 'float_num expected 3.14, got ' .. tostring(float_num) end
    if int_num ~= 3 then return false, 'int_num expected 3, got ' .. tostring(int_num) end
    if bool_val ~= true then return false, 'bool_val expected true, got ' .. tostring(bool_val) end
    return true, ''
end
