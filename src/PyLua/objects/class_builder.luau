local Base = require("./base")

local ClassBuilder = {}

type PyObject = Base.PyObject
type PyType = Base.PyType

type CallHelpers = {
	call: (vm: any, func: any, args: { PyObject }?, kwargs: { [string]: PyObject }?) -> PyObject,
	callWithLocals: (
		vm: any,
		func: any,
		args: { PyObject }?,
		kwargs: { [string]: PyObject }?,
		locals: { [string]: PyObject }?,
		captureLocals: boolean?
	) -> (PyObject, { [string]: PyObject }?),
}

local function ensurePy(value: any): PyObject
	if type(value) == "table" and value.__type ~= nil then
		return value
	end
	return Base.ensurePyObject(value)
end

local function resolveClassName(value: any): string
	if type(value) == "table" and value.__type == "str" then
		return value.__value
	elseif type(value) == "string" then
		return value
	end
	error("TypeError: class name must be a string", 2)
end

local function resolveModuleName(vm: any?): string
	if not vm or not vm.globals then
		return "__main__"
	end
	local candidate = vm.globals["__name__"]
	if type(candidate) == "table" and candidate.__type == "str" then
		return candidate.__value
	elseif type(candidate) == "string" then
		return candidate
	end
	return "__main__"
end

local function normalizeBases(rawBases: { PyObject }, defaultBase: PyType): { PyType }
	if #rawBases == 0 then
		return { defaultBase }
	end
	local resolved: { PyType } = {}
	for _, baseValue in ipairs(rawBases) do
		local baseObj = ensurePy(baseValue)
		local info = baseObj.__value
		local pyType: PyType?
		if baseObj.__type == "type" then
			if type(info) == "table" and (info :: any).pyType then
				pyType = (info :: any).pyType
			else
				local name = if type(info) == "table" and (info :: any).name then (info :: any).name else baseObj.__type
				pyType = Base.getTypeObject(name)
			end
		elseif baseObj.__type == "builtin_function_or_method" then
			local inner = info
			local name = if type(inner) == "table" then (inner :: any).name else nil
			if not name then
				error("TypeError: invalid base specification", 2)
			end
			pyType = Base.getTypeObject(name)
		else
			error("TypeError: base class must be a class or builtin type", 2)
		end
		resolved[#resolved + 1] = pyType :: PyType
	end
	return resolved
end

local function snapshotAttributes(
	namespace: { [string]: PyObject },
	className: string,
	moduleName: string
): { [string]: PyObject }
	local attrs: { [string]: PyObject } = {}
	for key, value in pairs(namespace) do
		if key ~= "__builtins__" then
			if type(value) == "table" and (value :: any).__nil then
				-- Skip nil sentinel entries
			else
				attrs[key] = ensurePy(value)
			end
		end
	end
	if not attrs["__module__"] then
		attrs["__module__"] = Base.ensurePyObject(moduleName)
	end
	if not attrs["__qualname__"] then
		attrs["__qualname__"] = Base.newPyObject("str", className)
	end
	attrs["__name__"] = Base.newPyObject("str", className)
	return attrs
end

function ClassBuilder.build(
	vm: any,
	helpers: CallHelpers,
	bodyFunc: PyObject,
	classNameValue: any,
	baseValues: { PyObject }
): PyObject
	if bodyFunc.__type ~= "function" then
		error("TypeError: class body must be a function", 2)
	end
	local className = resolveClassName(classNameValue)
	local moduleName = resolveModuleName(vm)
	local localsTable: { [string]: PyObject } = {
		["__module__"] = Base.ensurePyObject(moduleName),
		["__qualname__"] = Base.newPyObject("str", className),
	}
	local _, namespace = helpers.callWithLocals(vm, bodyFunc, {}, {}, localsTable, true)
	local defaultBase = Base.getTypeObject("object")
	local baseTypes = normalizeBases(baseValues, defaultBase)
	local attrs = snapshotAttributes(namespace or localsTable, className, moduleName)
	return Base.newClass(className, baseTypes, attrs)
end

return ClassBuilder
