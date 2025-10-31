local Collections = {}

local base = require("./base")
local builtins = require("./builtins")

type PyObject = base.PyObject
type PyType = base.PyType
export type PyList = PyObject & { __type: "list", __value: { PyObject } }
export type PyTuple = PyObject & { __type: "tuple", __value: { PyObject } }
export type PyDict = PyObject & { __type: "dict", __value: { [string]: { key: PyObject, value: PyObject } } }
export type PySet = PyObject & { __type: "set", __value: { [string]: { value: PyObject } } }
type MethodMap = { [string]: (PyObject, { PyObject }?) -> PyObject }

-- Helper utilities

-- Cache for hash keys to avoid repeated computation (uses weak keys for GC)
local hashCache = setmetatable({}, { __mode = "k" }) :: { [any]: string }

local function hashKey(obj: PyObject): string
	-- Quick cache lookup for frequently accessed objects
	local cached = hashCache[obj]
	if cached then
		return cached
	end

	local t = obj.__type
	local hash: string
	if t == "int" or t == "float" or t == "bool" or t == "str" then
		-- Use string.format for slightly better performance than concatenation
		hash = string.format("%s:%s", t, tostring(obj.__value))
	elseif t == "NoneType" then
		hash = "None"
	else
		hash = tostring(obj)
	end

	-- Cache the result (weak keys allow GC to clean up unused entries)
	hashCache[obj] = hash

	return hash
end

local function ensureIntIndex(value: PyObject, caller: string): number
	if value.__type ~= "int" then
		error("TypeError: " .. caller .. " indices must be integers", 2)
	end
	return value.__value :: number
end

local function resolveSequenceIndex(length: number, index: number, caller: string): number
	local idx = index
	if idx < 0 then
		idx += length
	end
	if idx < 0 or idx >= length then
		error("IndexError: " .. caller .. " index out of range", 2)
	end
	return idx + 1 -- convert to 1-based for Luau arrays
end

local function pyEquals(lhs: PyObject, rhs: PyObject): boolean
	if lhs == rhs then
		return true
	end
	local ok, eqMethod = pcall(function()
		return base.getattr(lhs, "__eq__")
	end)
	if ok and eqMethod then
		local result = base.call(eqMethod, { rhs })
		if type(result) == "table" and result.__type ~= nil then
			return base.truthy(result)
		elseif type(result) == "boolean" then
			return result
		end
		return base.truthy(base.ensurePyObject(result))
	end
	if lhs.__type == rhs.__type then
		local lv = lhs.__value
		local rv = rhs.__value
		if lv ~= nil and rv ~= nil then
			return lv == rv
		end
	end
	return false
end

local function sequenceContains(seq: { PyObject }, needle: PyObject): boolean
	for _, item in ipairs(seq) do
		if pyEquals(item, needle) then
			return true
		end
	end
	return false
end

local function boolResult(value: boolean): PyObject
	return base.newBool(value)
end

local function extractNumber(cell: PyObject, context: string): (number, boolean)
	if cell.__type == "int" then
		return cell.__value, false
	elseif cell.__type == "float" then
		return cell.__value, true
	end
	error("TypeError: " .. context .. " must contain numeric values", 2)
end

local function validateMatrix(listObj: PyObject, label: string): ({ PyObject }, number, number)
	if listObj.__type ~= "list" then
		error("TypeError: matrix multiplication requires list operands", 2)
	end
	local rows = listObj.__value :: { PyObject }
	if #rows == 0 then
		return rows, 0, 0
	end
	local firstRow = rows[1]
	if not firstRow or firstRow.__type ~= "list" then
		error("TypeError: " .. label .. " operand for @ must be a list of lists", 2)
	end
	local expectedCols = #(firstRow.__value :: { PyObject })
	for _, rowObj in ipairs(rows) do
		if rowObj.__type ~= "list" then
			error("TypeError: " .. label .. " operand for @ must be a list of lists", 2)
		end
		local rowValues = rowObj.__value :: { PyObject }
		if #rowValues ~= expectedCols then
			error("ValueError: inconsistent row lengths in " .. label .. " matrix", 2)
		end
	end
	return rows, #rows, expectedCols
end

local function matrixMultiply(left: PyObject, right: PyObject): PyObject
	local leftRows, leftRowCount, leftColCount = validateMatrix(left, "left")
	local rightRows, rightRowCount, rightColCount = validateMatrix(right, "right")
	if leftColCount ~= rightRowCount then
		error("ValueError: matrix dimension mismatch for @", 2)
	end
	local resultRows: { PyObject } = {}
	if leftRowCount == 0 or rightColCount == 0 then
		return Collections.newList(resultRows)
	end
	for i = 1, leftRowCount do
		local leftRowObj = leftRows[i]
		local leftValues = leftRowObj.__value :: { PyObject }
		local rowValues: { PyObject } = {}
		for j = 1, rightColCount do
			local sum = 0
			local sumHasFloat = false
			for k = 1, leftColCount do
				local rightRowObj = rightRows[k]
				local rightValues = rightRowObj.__value :: { PyObject }
				local leftCell = leftValues[k]
				local rightCell = rightValues[j]
				if not leftCell or not rightCell then
					error("ValueError: matrix dimension mismatch for @", 2)
				end
				local leftNumber, leftIsFloat = extractNumber(leftCell, "matrix")
				local rightNumber, rightIsFloat = extractNumber(rightCell, "matrix")
				local product = leftNumber * rightNumber
				sum += product
				sumHasFloat = sumHasFloat or leftIsFloat or rightIsFloat or (product % 1 ~= 0)
			end
			local cell: PyObject
			if sumHasFloat or (sum % 1 ~= 0) then
				cell = base.newFloat(sum)
			else
				cell = base.newInt(sum)
			end
			rowValues[#rowValues + 1] = cell
		end
		resultRows[#resultRows + 1] = Collections.newList(rowValues)
	end
	return Collections.newList(resultRows)
end

local getTypeObject = base.getTypeObject
local function ensureType(name: string)
	local ok = pcall(function()
		getTypeObject(name)
	end)
	if not ok then
		base.registerType(name, {})
	end
end

local function ensureMethods(pyType: PyType): MethodMap
	if not pyType.methods then
		pyType.methods = {} :: MethodMap
	end
	return pyType.methods :: MethodMap
end

ensureType("list")
ensureType("tuple")
ensureType("dict")
ensureType("set")
ensureType("list_iterator")

-- List implementation

function Collections.newList(values: { PyObject }?): PyList
	local arr: { PyObject } = {}
	if values then
		for i, v in ipairs(values) do
			arr[i] = base.ensurePyObject(v)
		end
	end
	return base.newPyObject("list", arr) :: PyList
end

do
	local listType = getTypeObject("list")
	local listMethods = ensureMethods(listType)

	listMethods["append"] = function(selfObj: PyObject, args: { PyObject }?)
		local value = args and args[1]
		if not value then
			error("TypeError: append() missing value", 2)
		end
		table.insert(selfObj.__value, base.ensurePyObject(value))
		return builtins.None()
	end

	listMethods["pop"] = function(selfObj: PyObject, args: { PyObject }?)
		local arr = selfObj.__value :: { PyObject }
		if #arr == 0 then
			error("IndexError: pop from empty list", 2)
		end
		local index: number
		if args and args[1] then
			local idxNum = ensureIntIndex(base.ensurePyObject(args[1]), "list")
			index = resolveSequenceIndex(#arr, idxNum, "list")
		else
			index = #arr
		end
		local removed = table.remove(arr, index)
		if not removed then
			error("IndexError: pop index invalid", 2)
		end
		return removed
	end

	listMethods["__len__"] = function(selfObj: PyObject)
		return base.newInt(#(selfObj.__value :: { PyObject }))
	end

	listMethods["__iter__"] = function(selfObj: PyObject)
		local iterState = { index = 0, list = selfObj }
		local iterator = base.newPyObject("list_iterator", iterState)
		local iterType = getTypeObject("list_iterator")
		local iterMethods = ensureMethods(iterType)
		if not iterMethods["__next__"] then
			iterMethods["__next__"] = function(it: PyObject)
				local state = it.__value
				state.index += 1
				local arr = state.list.__value :: { PyObject }
				if state.index > #arr then
					error("StopIteration", 2)
				end
				return arr[state.index]
			end
		end
		return iterator
	end

	listMethods["__add__"] = function(selfObj: PyObject, args: { PyObject }?)
		local other = args and args[1]
		if not other or other.__type ~= "list" then
			error("TypeError: can only concatenate list (not '" .. (other and other.__type or "nil") .. "') to list", 2)
		end
		local selfArr = selfObj.__value :: { PyObject }
		local otherArr = other.__value :: { PyObject }
		-- Pre-allocate combined array with known size
		local combined = table.create(#selfArr + #otherArr)
		local idx = 1
		for _, item in ipairs(selfArr) do
			combined[idx] = item
			idx += 1
		end
		for _, item in ipairs(otherArr) do
			combined[idx] = item
			idx += 1
		end
		return Collections.newList(combined)
	end

	listMethods["__getitem__"] = function(selfObj: PyObject, args: { PyObject }?)
		if not args or not args[1] then
			error("TypeError: list indices must be integers", 2)
		end
		local idxNum = ensureIntIndex(base.ensurePyObject(args[1]), "list")
		local arr = selfObj.__value :: { PyObject }
		local resolved = resolveSequenceIndex(#arr, idxNum, "list")
		return arr[resolved]
	end

	listMethods["__setitem__"] = function(selfObj: PyObject, args: { PyObject }?)
		if not args or #args < 2 then
			error("TypeError: list assignment requires index and value", 2)
		end
		local idxNum = ensureIntIndex(base.ensurePyObject(args[1]), "list")
		local value = base.ensurePyObject(args[2])
		local arr = selfObj.__value :: { PyObject }
		local resolved = resolveSequenceIndex(#arr, idxNum, "list")
		arr[resolved] = value
		return builtins.None()
	end

	listMethods["__contains__"] = function(selfObj: PyObject, args: { PyObject }?)
		if not args or not args[1] then
			return boolResult(false)
		end
		local needle = base.ensurePyObject(args[1])
		local found = sequenceContains(selfObj.__value :: { PyObject }, needle)
		return boolResult(found)
	end

	listMethods["__matmul__"] = function(selfObj: PyObject, args: { PyObject }?)
		local other = args and args[1]
		if not other then
			error("TypeError: matrix multiplication requires right operand", 2)
		end
		return matrixMultiply(selfObj, base.ensurePyObject(other))
	end

	listMethods["__rmatmul__"] = function(selfObj: PyObject, args: { PyObject }?)
		local other = args and args[1]
		if not other then
			error("TypeError: matrix multiplication requires left operand", 2)
		end
		return matrixMultiply(base.ensurePyObject(other), selfObj)
	end
end

-- Tuple implementation (immutable)

function Collections.newTuple(values: { PyObject }?): PyTuple
	local arr: { PyObject } = {}
	if values then
		for i, v in ipairs(values) do
			arr[i] = base.ensurePyObject(v)
		end
	end
	return base.newPyObject("tuple", arr) :: PyTuple
end

do
	local tupleType = getTypeObject("tuple")
	local tupleMethods = ensureMethods(tupleType)

	tupleMethods["__len__"] = function(selfObj: PyObject)
		return base.newInt(#(selfObj.__value :: { PyObject }))
	end

	tupleMethods["__iter__"] = function(selfObj: PyObject)
		local listVersion: PyObject = Collections.newList(selfObj.__value)
		local iterMethod = base.getattr(listVersion, "__iter__")
		return base.call(iterMethod, {})
	end

	tupleMethods["__getitem__"] = function(selfObj: PyObject, args: { PyObject }?)
		if not args or not args[1] then
			error("TypeError: tuple indices must be integers", 2)
		end
		local idxNum = ensureIntIndex(base.ensurePyObject(args[1]), "tuple")
		local arr = selfObj.__value :: { PyObject }
		local resolved = resolveSequenceIndex(#arr, idxNum, "tuple")
		return arr[resolved]
	end

	tupleMethods["__contains__"] = function(selfObj: PyObject, args: { PyObject }?)
		if not args or not args[1] then
			return boolResult(false)
		end
		local needle = base.ensurePyObject(args[1])
		local found = sequenceContains(selfObj.__value :: { PyObject }, needle)
		return boolResult(found)
	end
end

-- Dict implementation

function Collections.newDict(entries: { { PyObject } }?): PyDict
	local storage: { [string]: { key: PyObject, value: PyObject } } = {}
	if entries then
		for _, pair in ipairs(entries) do
			local keyObj = base.ensurePyObject(pair[1])
			local valueObj = base.ensurePyObject(pair[2])
			storage[hashKey(keyObj)] = { key = keyObj, value = valueObj }
		end
	end
	return base.newPyObject("dict", storage) :: PyDict
end

do
	local dictType = getTypeObject("dict")
	local dictMethods = ensureMethods(dictType)

	dictMethods["set"] = function(selfObj: PyObject, args: { PyObject }?)
		if not args or #args < 2 then
			error("TypeError: set requires key and value", 2)
		end
		local key = base.ensurePyObject((args :: any)[1])
		local value = base.ensurePyObject((args :: any)[2])
		local store = selfObj.__value :: { [string]: { key: PyObject, value: PyObject } }
		store[hashKey(key)] = { key = key, value = value }
		return builtins.None()
	end

	dictMethods["get"] = function(selfObj: PyObject, args: { PyObject }?)
		if not args or #args < 1 then
			error("TypeError: get requires key", 2)
		end
		local key = base.ensurePyObject((args :: any)[1])
		local entry = (selfObj.__value :: any)[hashKey(key)]
		if entry then
			return entry.value
		end
		if args and (args :: any)[2] then
			return (args :: any)[2]
		end
		return builtins.None()
	end

	dictMethods["__len__"] = function(selfObj: PyObject)
		local count = 0
		for _ in pairs(selfObj.__value) do
			count += 1
		end
		return base.newInt(count)
	end

	dictMethods["__getitem__"] = function(selfObj: PyObject, args: { PyObject }?)
		if not args or not args[1] then
			error("TypeError: dict indices must be provided", 2)
		end
		local key = base.ensurePyObject(args[1])
		local entry = (selfObj.__value :: any)[hashKey(key)]
		if not entry then
			error("KeyError: " .. tostring(key.__value), 2)
		end
		return entry.value
	end

	dictMethods["__setitem__"] = function(selfObj: PyObject, args: { PyObject }?)
		if not args or #args < 2 then
			error("TypeError: dict assignment requires key and value", 2)
		end
		local key = base.ensurePyObject(args[1])
		local value = base.ensurePyObject(args[2])
		local store = selfObj.__value :: { [string]: { key: PyObject, value: PyObject } }
		store[hashKey(key)] = { key = key, value = value }
		return builtins.None()
	end

	dictMethods["__contains__"] = function(selfObj: PyObject, args: { PyObject }?)
		if not args or not args[1] then
			return boolResult(false)
		end
		local key = base.ensurePyObject(args[1])
		local entry = (selfObj.__value :: any)[hashKey(key)]
		return boolResult(entry ~= nil)
	end

	dictMethods["keys"] = function(selfObj: PyObject)
		local values: { PyObject } = {}
		for _, entry in pairs(selfObj.__value) do
			values[#values + 1] = entry.key
		end
		return Collections.newList(values)
	end

	dictMethods["values"] = function(selfObj: PyObject)
		local values: { PyObject } = {}
		for _, entry in pairs(selfObj.__value) do
			values[#values + 1] = entry.value
		end
		return Collections.newList(values)
	end

	dictMethods["items"] = function(selfObj: PyObject)
		local pairsList: { PyObject } = {}
		for _, entry in pairs(selfObj.__value) do
			pairsList[#pairsList + 1] = Collections.newTuple({ entry.key, entry.value })
		end
		return Collections.newList(pairsList)
	end
end

-- Set implementation

function Collections.newSet(values: { PyObject }?): PySet
	local storage: { [string]: { value: PyObject } } = {}
	if values then
		for _, v in ipairs(values) do
			local valueObj = base.ensurePyObject(v)
			storage[hashKey(valueObj)] = { value = valueObj }
		end
	end
	return base.newPyObject("set", storage) :: PySet
end

do
	local setType = getTypeObject("set")
	local setMethods = ensureMethods(setType)

	setMethods["add"] = function(selfObj: PyObject, args: { PyObject }?)
		local value = args and args[1]
		if not value then
			error("TypeError: add requires value", 2)
		end
		local ensured = base.ensurePyObject(value)
		local store = selfObj.__value :: { [string]: { value: PyObject } }
		store[hashKey(ensured)] = { value = ensured }
		return builtins.None()
	end

	setMethods["__len__"] = function(selfObj: PyObject)
		local count = 0
		for _ in pairs(selfObj.__value) do
			count += 1
		end
		return base.newInt(count)
	end

	setMethods["__contains__"] = function(selfObj: PyObject, args: { PyObject }?)
		if not args or not args[1] then
			return boolResult(false)
		end
		local value = base.ensurePyObject(args[1])
		return boolResult((selfObj.__value :: any)[hashKey(value)] ~= nil)
	end

	setMethods["remove"] = function(selfObj: PyObject, args: { PyObject }?)
		if not args or not args[1] then
			error("TypeError: remove() requires a value", 2)
		end
		local value = base.ensurePyObject(args[1])
		local key = hashKey(value)
		local store: any = selfObj.__value
		if not store[key] then
			error("KeyError: value not found in set", 2)
		end
		store[key] = nil
		return builtins.None()
	end

	setMethods["discard"] = function(selfObj: PyObject, args: { PyObject }?)
		if not args or not args[1] then
			error("TypeError: discard() requires a value", 2)
		end
		local value = base.ensurePyObject(args[1])
		local store = selfObj.__value :: { [string]: { value: PyObject } }
		store[hashKey(value)] = nil
		return builtins.None()
	end
end

-- Public API shortcuts
Collections.list = Collections.newList
Collections.tuple = Collections.newTuple
Collections.dict = Collections.newDict
Collections.set = Collections.newSet

return Collections
