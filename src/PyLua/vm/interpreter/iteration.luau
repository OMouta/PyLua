local Base = require("../../objects/base")

local Iteration = {}

export type PyObject = Base.PyObject

function Iteration.createIterator(iterable: any): any
	if type(iterable) == "table" then
		local obj = iterable :: any
		if obj.__type == "list" then
			return {
				__type = "list_iterator",
				__value = obj.__value,
				__index = 1,
				__length = #obj.__value,
			}
		elseif obj.__type == "tuple" then
			return {
				__type = "tuple_iterator",
				__value = obj.__value,
				__index = 1,
				__length = #obj.__value,
			}
		elseif obj.__type == "set" then
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
		elseif obj.__type == "dict" then
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
		elseif obj.__type == "str" then
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
		elseif obj.__type == "range" then
			local data = obj.__value
			return {
				__type = "range_iterator",
				__value = {
					current = data.start,
					stop = data.stop,
					step = data.step,
				},
			}
		end
	end

	error("TypeError: '" .. tostring(type(iterable)) .. "' object is not iterable", 2)
end

function Iteration.getNextValue(iterator: any): any?
	if type(iterator) == "table" then
		local iter = iterator :: any
		if iter.__type == "range_iterator" then
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
		end
	end

	return nil
end

return Iteration
