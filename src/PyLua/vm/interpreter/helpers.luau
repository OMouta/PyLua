local Base = require("../../objects/base")

local Helpers = {}

export type PyObject = Base.PyObject

local function isPyObject(value: any): boolean
	return type(value) == "table" and value.__type ~= nil and value.__typeobj ~= nil
end

local function coercePyObject(value: any): PyObject
	if isPyObject(value) then
		return value :: PyObject
	end
	return Base.ensurePyObject(value)
end

local function coerceSingletonCandidate(value: any): any
	if isPyObject(value) then
		return value
	end
	local valueType = typeof(value)
	if valueType == "boolean" then
		return Base.newBool(value)
	elseif value == nil then
		return Base.newNone()
	end
	return value
end

local function pyEquals(lhs: PyObject, rhs: PyObject): boolean
	if lhs == rhs then
		return true
	end
	local ok, method = pcall(function()
		return Base.getattr(lhs, "__eq__")
	end)
	if ok and method then
		local result = Base.call(method, { rhs })
		local resultObj = coercePyObject(result)
		return Base.truthy(resultObj)
	end
	if lhs.__type == rhs.__type then
		local lval = lhs.__value
		local rval = rhs.__value
		if lval ~= nil and rval ~= nil then
			return lval == rval
		end
	end
	return false
end

local function identityCompare(left: any, right: any): boolean
	if left == right then
		return true
	end
	local coercedLeft = coerceSingletonCandidate(left)
	local coercedRight = coerceSingletonCandidate(right)
	local leftIsPy = isPyObject(coercedLeft)
	local rightIsPy = isPyObject(coercedRight)
	if leftIsPy and rightIsPy then
		return coercedLeft == coercedRight
	end
	if leftIsPy or rightIsPy then
		return false
	end
	return coercedLeft == coercedRight
end

local function iterMembershipContains(container: PyObject, needle: PyObject): boolean
	local okIter, iterMethod = pcall(function()
		return Base.getattr(container, "__iter__")
	end)
	if not okIter or not iterMethod then
		error("TypeError: argument of type '" .. tostring(container.__type) .. "' is not iterable", 2)
	end
	local iterator = Base.call(iterMethod, {})
	local okNext, nextMethod = pcall(function()
		return Base.getattr(iterator, "__next__")
	end)
	if not okNext or not nextMethod then
		error("TypeError: argument of type '" .. tostring(container.__type) .. "' is not iterable", 2)
	end
	while true do
		local okItem, itemOrErr = pcall(function()
			return Base.call(nextMethod, {})
		end)
		if okItem then
			local itemObj = coercePyObject(itemOrErr)
			if pyEquals(itemObj, needle) then
				return true
			end
		else
			if type(itemOrErr) == "table" and (itemOrErr :: any).__type == "StopIteration" then
				return false
			end
			local errMessage = tostring(itemOrErr)
			if string.find(errMessage, "StopIteration", 1, true) ~= nil then
				return false
			end
			error(itemOrErr, 0)
		end
	end
end

local function membershipContains(needle: PyObject, container: PyObject): boolean
	local okContains, containsMethod = pcall(function()
		return Base.getattr(container, "__contains__")
	end)
	if okContains and containsMethod then
		local result = Base.call(containsMethod, { needle })
		local resultObj = coercePyObject(result)
		return Base.truthy(resultObj)
	end
	return iterMembershipContains(container, needle)
end

local compareOperations = {
	[0] = function(a: any, b: any): boolean
		return a < b
	end,
	[1] = function(a: any, b: any): boolean
		return a <= b
	end,
	[2] = function(a: any, b: any): boolean
		return a == b
	end,
	[3] = function(a: any, b: any): boolean
		return a ~= b
	end,
	[4] = function(a: any, b: any): boolean
		return a > b
	end,
	[5] = function(a: any, b: any): boolean
		return a >= b
	end,
	[6] = function(a: any, b: any): boolean
		return identityCompare(a, b)
	end,
	[7] = function(a: any, b: any): boolean
		return not identityCompare(a, b)
	end,
	[8] = function(a: any, b: any): boolean
		local needle = coercePyObject(a)
		local container = coercePyObject(b)
		return membershipContains(needle, container)
	end,
	[9] = function(a: any, b: any): boolean
		local needle = coercePyObject(a)
		local container = coercePyObject(b)
		return not membershipContains(needle, container)
	end,
}

local function unwrapPrimitive(value: any): any
	if type(value) == "table" and value.__type ~= nil then
		local t = value.__type
		if t == "NoneType" then
			return nil
		end
		local inner = value.__value
		if inner ~= nil then
			if t == "int" or t == "float" or t == "bool" or t == "str" then
				return inner
			end
		end
	end
	return value
end

Helpers.isPyObject = isPyObject
Helpers.coercePyObject = coercePyObject
Helpers.coerceSingletonCandidate = coerceSingletonCandidate
Helpers.pyEquals = pyEquals
Helpers.identityCompare = identityCompare
Helpers.iterMembershipContains = iterMembershipContains
Helpers.membershipContains = membershipContains
Helpers.compareOperations = compareOperations
Helpers.unwrapPrimitive = unwrapPrimitive

return Helpers
