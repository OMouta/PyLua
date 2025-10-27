local Base = require("../../objects/base")

local Iteration = {}

local ITERATOR_TYPES = {
	list_iterator = true,
	tuple_iterator = true,
	set_iterator = true,
	dict_iterator = true,
	str_iterator = true,
}

export type PyObject = Base.PyObject

function Iteration.createIterator(iterable: any): any
	local obj = iterable
	if type(obj) ~= "table" or obj.__type == nil then
		obj = Base.ensurePyObject(iterable)
	end

	local objType = obj.__type
	if objType == "list" then
		local listValues = obj.__value :: { PyObject }
		return {
			__type = "list_iterator",
			__value = listValues,
			__index = 1,
			__length = #listValues,
		}
	elseif objType == "tuple" then
		local tupleValues = obj.__value :: { PyObject }
		return {
			__type = "tuple_iterator",
			__value = tupleValues,
			__index = 1,
			__length = #tupleValues,
		}
	elseif objType == "set" then
		local arr = {}
		for _, entry in pairs(obj.__value) do
			arr[#arr + 1] = entry.value
		end
		return {
			__type = "set_iterator",
			__value = arr,
			__index = 1,
			__length = #arr,
		}
	elseif objType == "dict" then
		local keys = {}
		for _, entry in pairs(obj.__value) do
			keys[#keys + 1] = entry.key
		end
		return {
			__type = "dict_iterator",
			__value = keys,
			__index = 1,
			__length = #keys,
		}
	elseif objType == "str" then
		local chars = {}
		local str = obj.__value :: string
		for i = 1, #str do
			chars[i] = Base.newPyObject("str", str:sub(i, i))
		end
		return {
			__type = "str_iterator",
			__value = chars,
			__index = 1,
			__length = #chars,
		}
	elseif objType == "range" then
		local data = obj.__value
		return {
			__type = "range_iterator",
			__value = {
				current = data.start,
				stop = data.stop,
				step = data.step,
			},
		}
	elseif objType == "generator" then
		return obj
	elseif objType and ITERATOR_TYPES[objType] then
		return obj
	end

	local okIter, iterMethod = pcall(function()
		return Base.getattr(obj, "__iter__")
	end)
	if okIter and iterMethod then
		return Base.call(iterMethod, {})
	end

	error("TypeError: '" .. tostring(objType or type(iterable)) .. "' object is not iterable", 2)
end

function Iteration.getNextValue(iterator: any): any?
	if type(iterator) == "table" then
		local iter = iterator :: any
		local iterType = iter.__type
		if iterType == "range_iterator" then
			local state = iter.__value
			local current = state.current
			local step = state.step
			local stop = state.stop
			if step > 0 then
				if current >= stop then
					return nil
				end
			else
				if current <= stop then
					return nil
				end
			end
			state.current = current + step
			return Base.newInt(current)
		elseif iter.__index and iter.__length and iter.__index <= iter.__length then
			local value = iter.__value[iter.__index]
			iter.__index = iter.__index + 1
			return value
		elseif iter.__typeobj ~= nil then
			local okNext, nextMethod = pcall(function()
				return Base.getattr(iter, "__next__")
			end)
			if okNext and nextMethod then
				local okCall, resultOrErr = pcall(function()
					return Base.call(nextMethod, {})
				end)
				if okCall then
					return resultOrErr
				else
					local err = resultOrErr
					if type(err) == "table" and err.__type == "StopIteration" then
						return nil
					end
					local errMessage = tostring(err)
					if string.find(errMessage, "StopIteration", 1, true) then
						return nil
					end
					error(err, 0)
				end
			end
		end
	end

	return nil
end

return Iteration
