-- PyLua 0.2 Object System
-- Handles Python-specific data types and objects that don't map directly to Lua types

local Objects = {}

-- Object type constants
local ObjectTypes = {
    LIST = "list",
    DICT = "dict", 
    TUPLE = "tuple",
    SET = "set",
    CLASS = "class",
    INSTANCE = "instance",
    FUNCTION = "function",
    MODULE = "module",
    NONE = "NoneType",
}

-- Base PyObject structure
local function createPyObject(objectType, value, methods)
    return {
        __type = objectType,
        __value = value or {},
        __methods = methods or {},
        __class = nil,
        __dict = {},  -- For storing attributes
    }
end

-- === PYTHON LIST ===
local listMethods = {}

listMethods.append = function(self, item)
    table.insert(self.__value, item)
    return Objects.createNone()
end

listMethods.extend = function(self, iterable)
    if iterable.__type == ObjectTypes.LIST then
        for _, item in ipairs(iterable.__value) do
            table.insert(self.__value, item)
        end
    else
        error("extend() argument must be iterable")
    end
    return Objects.createNone()
end

listMethods.insert = function(self, index, item)
    -- Python uses 0-based indexing, Lua uses 1-based
    table.insert(self.__value, index + 1, item)
    return Objects.createNone()
end

listMethods.remove = function(self, item)
    for i, v in ipairs(self.__value) do
        if v == item then
            table.remove(self.__value, i)
            return Objects.createNone()
        end
    end
    error("list.remove(x): x not in list")
end

listMethods.pop = function(self, index)
    local idx = index and (index + 1) or #self.__value  -- Default to last item
    if idx < 1 or idx > #self.__value then
        error("pop index out of range")
    end
    return table.remove(self.__value, idx)
end

listMethods.index = function(self, item)
    for i, v in ipairs(self.__value) do
        if v == item then
            return i - 1  -- Convert to Python 0-based indexing
        end
    end
    error("ValueError: " .. tostring(item) .. " is not in list")
end

listMethods.count = function(self, item)
    local count = 0
    for _, v in ipairs(self.__value) do
        if v == item then
            count = count + 1
        end
    end
    return count
end

listMethods.sort = function(self, reverse)
    if reverse then
        table.sort(self.__value, function(a, b) return a > b end)
    else
        table.sort(self.__value)
    end
    return Objects.createNone()
end

listMethods.reverse = function(self)
    local reversed = {}
    for i = #self.__value, 1, -1 do
        table.insert(reversed, self.__value[i])
    end
    self.__value = reversed
    return Objects.createNone()
end

function Objects.createList(items)
    items = items or {}
    return createPyObject(ObjectTypes.LIST, items, listMethods)
end

-- === PYTHON TUPLE ===
local tupleMethods = {}

tupleMethods.index = function(self, item)
    for i, v in ipairs(self.__value) do
        if v == item then
            return i - 1  -- Convert to Python 0-based indexing
        end
    end
    error("ValueError: tuple.index(x): x not in tuple")
end

tupleMethods.count = function(self, item)
    local count = 0
    for _, v in ipairs(self.__value) do
        if v == item then
            count = count + 1
        end
    end
    return count
end

function Objects.createTuple(items)
    items = items or {}
    local tuple = createPyObject(ObjectTypes.TUPLE, items, tupleMethods)
    -- Tuples are immutable, so we make the value read-only
    return tuple
end

-- === PYTHON DICTIONARY ===
local dictMethods = {}

dictMethods.get = function(self, key, default)
    local value = self.__value[key]
    return value ~= nil and value or default
end

dictMethods.keys = function(self)
    local keys = {}
    for k, _ in pairs(self.__value) do
        table.insert(keys, k)
    end
    return Objects.createList(keys)
end

dictMethods.values = function(self)
    local values = {}
    for _, v in pairs(self.__value) do
        table.insert(values, v)
    end
    return Objects.createList(values)
end

dictMethods.items = function(self)
    local items = {}
    for k, v in pairs(self.__value) do
        table.insert(items, Objects.createTuple({k, v}))
    end
    return Objects.createList(items)
end

dictMethods.pop = function(self, key, default)
    local value = self.__value[key]
    if value ~= nil then
        self.__value[key] = nil
        return value
    elseif default ~= nil then
        return default
    else
        error("KeyError: " .. tostring(key))
    end
end

dictMethods.update = function(self, other)
    if other.__type == ObjectTypes.DICT then
        for k, v in pairs(other.__value) do
            self.__value[k] = v
        end
    else
        error("update() argument must be dict")
    end
    return Objects.createNone()
end

function Objects.createDict(items)
    items = items or {}
    return createPyObject(ObjectTypes.DICT, items, dictMethods)
end

-- === PYTHON SET ===
local setMethods = {}

setMethods.add = function(self, item)
    self.__value[item] = true
    return Objects.createNone()
end

setMethods.remove = function(self, item)
    if self.__value[item] then
        self.__value[item] = nil
        return Objects.createNone()
    else
        error("KeyError: " .. tostring(item))
    end
end

setMethods.discard = function(self, item)
    self.__value[item] = nil
    return Objects.createNone()
end

setMethods.union = function(self, other)
    local result = {}
    for k, _ in pairs(self.__value) do
        result[k] = true
    end
    if other.__type == ObjectTypes.SET then
        for k, _ in pairs(other.__value) do
            result[k] = true
        end
    end
    return Objects.createSet(result)
end

setMethods.intersection = function(self, other)
    local result = {}
    if other.__type == ObjectTypes.SET then
        for k, _ in pairs(self.__value) do
            if other.__value[k] then
                result[k] = true
            end
        end
    end
    return Objects.createSet(result)
end

function Objects.createSet(items)
    items = items or {}
    return createPyObject(ObjectTypes.SET, items, setMethods)
end

-- === NONE TYPE ===
function Objects.createNone()
    return createPyObject(ObjectTypes.NONE, nil, {})
end

-- === UTILITY FUNCTIONS ===

-- Convert Python object to Lua representation for operations
function Objects.toPython(value)
    if type(value) == "table" and value.__type then
        return value  -- Already a Python object
    elseif type(value) == "table" then
        -- Convert Lua table to Python list (default behavior)
        return Objects.createList(value)
    else
        return value  -- Primitive types stay as-is
    end
end

-- Convert Python object to Lua for native operations
function Objects.toLua(pyObject)
    if type(pyObject) == "table" and pyObject.__type then
        if pyObject.__type == ObjectTypes.LIST or pyObject.__type == ObjectTypes.TUPLE then
            return pyObject.__value
        elseif pyObject.__type == ObjectTypes.DICT then
            return pyObject.__value
        elseif pyObject.__type == ObjectTypes.NONE then
            return nil
        else
            return pyObject.__value
        end
    else
        return pyObject  -- Already Lua value
    end
end

-- Get the length of a Python object
function Objects.getLength(pyObject)
    if type(pyObject) == "table" and pyObject.__type then
        if pyObject.__type == ObjectTypes.LIST or pyObject.__type == ObjectTypes.TUPLE then
            return #pyObject.__value
        elseif pyObject.__type == ObjectTypes.DICT or pyObject.__type == ObjectTypes.SET then
            local count = 0
            for _ in pairs(pyObject.__value) do
                count = count + 1
            end
            return count
        else
            error("object of type '" .. pyObject.__type .. "' has no len()")
        end
    elseif type(pyObject) == "string" then
        return string.len(pyObject)
    elseif type(pyObject) == "table" then
        return #pyObject
    else
        error("object of type '" .. type(pyObject) .. "' has no len()")
    end
end

-- Get an item from a Python object (indexing)
function Objects.getItem(pyObject, index)
    if type(pyObject) == "table" and pyObject.__type then
        if pyObject.__type == ObjectTypes.LIST or pyObject.__type == ObjectTypes.TUPLE then
            local luaIndex = index + 1  -- Convert to 1-based indexing
            if luaIndex < 1 or luaIndex > #pyObject.__value then
                error("IndexError: list index out of range")
            end
            return pyObject.__value[luaIndex]
        elseif pyObject.__type == ObjectTypes.DICT then
            local value = pyObject.__value[index]
            if value == nil then
                error("KeyError: " .. tostring(index))
            end
            return value
        else
            error("'" .. pyObject.__type .. "' object is not subscriptable")
        end
    elseif type(pyObject) == "string" then
        local luaIndex = index + 1
        if luaIndex < 1 or luaIndex > string.len(pyObject) then
            error("IndexError: string index out of range")
        end
        return string.sub(pyObject, luaIndex, luaIndex)
    else
        error("'" .. type(pyObject) .. "' object is not subscriptable")
    end
end

-- Set an item in a Python object
function Objects.setItem(pyObject, index, value)
    if type(pyObject) == "table" and pyObject.__type then
        if pyObject.__type == ObjectTypes.LIST then
            local luaIndex = index + 1
            if luaIndex < 1 or luaIndex > #pyObject.__value then
                error("IndexError: list assignment index out of range")
            end
            pyObject.__value[luaIndex] = value
        elseif pyObject.__type == ObjectTypes.DICT then
            pyObject.__value[index] = value
        elseif pyObject.__type == ObjectTypes.TUPLE then
            error("TypeError: 'tuple' object does not support item assignment")
        else
            error("'" .. pyObject.__type .. "' object does not support item assignment")
        end
    else
        error("'" .. type(pyObject) .. "' object does not support item assignment")
    end
end

-- Call a method on a Python object
function Objects.callMethod(pyObject, methodName, args)
    if type(pyObject) == "table" and pyObject.__type and pyObject.__methods[methodName] then
        return pyObject.__methods[methodName](pyObject, table.unpack(args or {}))
    else
        error("'" .. (pyObject.__type or type(pyObject)) .. "' object has no attribute '" .. methodName .. "'")
    end
end

-- Check if an object is iterable
function Objects.isIterable(pyObject)
    if type(pyObject) == "table" and pyObject.__type then
        return pyObject.__type == ObjectTypes.LIST or 
               pyObject.__type == ObjectTypes.TUPLE or
               pyObject.__type == ObjectTypes.SET or
               pyObject.__type == ObjectTypes.DICT
    elseif type(pyObject) == "string" or type(pyObject) == "table" then
        return true
    else
        return false
    end
end

-- Create an iterator for a Python object
function Objects.createIterator(pyObject)
    if not Objects.isIterable(pyObject) then
        error("'" .. (pyObject.__type or type(pyObject)) .. "' object is not iterable")
    end
    
    if type(pyObject) == "table" and pyObject.__type then
        if pyObject.__type == ObjectTypes.LIST or pyObject.__type == ObjectTypes.TUPLE then
            return {
                type = "sequence",
                data = pyObject.__value,
                index = 1,
                length = #pyObject.__value
            }
        elseif pyObject.__type == ObjectTypes.DICT then
            local keys = {}
            for k, _ in pairs(pyObject.__value) do
                table.insert(keys, k)
            end
            return {
                type = "sequence", 
                data = keys,
                index = 1,
                length = #keys
            }
        elseif pyObject.__type == ObjectTypes.SET then
            local items = {}
            for k, _ in pairs(pyObject.__value) do
                table.insert(items, k)
            end
            return {
                type = "sequence",
                data = items, 
                index = 1,
                length = #items
            }
        end
    elseif type(pyObject) == "string" then
        local chars = {}
        for i = 1, string.len(pyObject) do
            table.insert(chars, string.sub(pyObject, i, i))
        end
        return {
            type = "sequence",
            data = chars,
            index = 1, 
            length = #chars
        }
    elseif type(pyObject) == "table" then
        -- Plain Lua table, treat as list
        return {
            type = "sequence",
            data = pyObject,
            index = 1,
            length = #pyObject
        }
    end
    
    -- Fallback return - this should never be reached due to the isIterable check above
    error("Unable to create iterator for object of type '" .. (pyObject.__type or type(pyObject)) .. "'")
end

-- Export object types for external use
Objects.ObjectTypes = ObjectTypes

return Objects
