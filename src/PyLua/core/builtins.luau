-- PyLua 0.2 Built-in Functions
-- Standard library implementations for Python built-in functions

local Builtins = {}

-- Built-in functions registry
local builtins = {}

-- print() function
builtins["print"] = function(...)
    local args = {...}
    local output = ""
    for i, arg in ipairs(args) do
        if i > 1 then output = output .. " " end
        output = output .. tostring(arg)
    end
    print(output)
    return nil -- Python print returns None
end

-- range() function
builtins["range"] = function(...)
    local args = {...}
    -- Range implementation that returns an iterable list
    if #args == 1 then
        local result = {}
        for i = 0, args[1] - 1 do
            table.insert(result, i)
        end
        return result
    elseif #args == 2 then
        local result = {}
        for i = args[1], args[2] - 1 do
            table.insert(result, i)
        end
        return result
    elseif #args == 3 then
        local result = {}
        for i = args[1], args[2] - 1, args[3] do
            table.insert(result, i)
        end
        return result
    else
        error("range() requires 1, 2, or 3 arguments")
    end
end

-- len() function
builtins["len"] = function(obj) -- Changed from function(args)
    -- if #args ~= 1 then -- Removed argument count check
    --     error("len() takes exactly one argument")
    -- end
    -- local obj = args[1] -- Removed: obj is now the direct first parameter

    if obj == nil then -- Added a basic check for nil
        error("len() takes exactly one argument (received nil)")
    end
    
    -- Check if it's a Python object first
    if type(obj) == "table" and obj.__type then
        -- Import objects module locally to avoid circular dependency
        local objects = require(script.Parent.objects)
        return objects.getLength(obj)
    elseif type(obj) == "table" then
        return #obj
    elseif type(obj) == "string" then
        return string.len(obj)
    else
        error("object of type '" .. type(obj) .. "' has no len()")
    end
end

-- type() function
builtins["type"] = function(obj)
    local luaType = type(obj)
    -- Convert Lua types to Python types
    if luaType == "number" then
        if obj % 1 == 0 then
            return "int"
        else
            return "float"
        end
    elseif luaType == "string" then
        return "str"
    elseif luaType == "boolean" then
        return "bool"
    elseif luaType == "table" then
        -- Check if it's a Python object with __type field
        if obj.__type then
            return obj.__type
        else
            return "list"  -- Default for plain tables
        end
    else
        return "object"
    end
end

-- str() function
builtins["str"] = function(obj)
    return tostring(obj)
end

-- int() function
builtins["int"] = function(value)
    if type(value) == "number" then
        return math.floor(value)
    elseif type(value) == "string" then
        local num = tonumber(value)
        if num then
            return math.floor(num)
        else
            error("invalid literal for int() with base 10: '" .. value .. "'")
        end
    else
        error("int() argument must be a string or a number, not '" .. type(value) .. "'")
    end
end

-- float() function
builtins["float"] = function(value)
    if type(value) == "number" then
        return value
    elseif type(value) == "string" then
        local num = tonumber(value)
        if num then
            return num
        else
            error("could not convert string to float: '" .. value .. "'")
        end
    else
        error("float() argument must be a string or a number, not '" .. type(value) .. "'")
    end
end

-- bool() function
builtins["bool"] = function(value)
    if value == nil then
        return false
    elseif value == nil or value == false then
        return false
    elseif value == 0 or value == "" then
        return false
    elseif type(value) == "table" and #value == 0 then
        return false
    else
        return true
    end
end

-- Python boolean constants
builtins["True"] = true
builtins["False"] = false
builtins["None"] = "__PYLUA_NIL__"  -- Use placeholder for None since Lua tables can't store nil

-- Public API
function Builtins.getBuiltins()
    return builtins
end

function Builtins.getBuiltin(name)
    return builtins[name]
end

return Builtins
