local Base = require("./base")

local Module = {}

-- Register the module type
local moduleType = Base.registerType("module", {
	bases = { Base.getTypeObject("object") },
})

function Module.new(name: string, doc: string?): Base.PyObject
	local dict = {
		["__name__"] = Base.newPyObject("str", name),
		["__doc__"] = if doc then Base.newPyObject("str", doc) else Base.newNone(),
		["__package__"] = Base.newNone(),
		["__loader__"] = Base.newNone(),
		["__spec__"] = Base.newNone(),
	}

	local moduleObj = {
		__type = "module",
		__value = nil,
		__dict = dict,
		__typeobj = moduleType,
	}

	return moduleObj
end

return Module
