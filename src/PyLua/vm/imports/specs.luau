--!strict
-- ModuleSpec: PEP 451-inspired module specification
-- Describes how a module should be loaded

local Base = require("../../objects/base")
local Collections = require("../../objects/collections")

local ModuleSpec = {}

export type Loader = {
	create_module: ((spec: ModuleSpec) -> Base.PyObject?)?,
	exec_module: (spec: ModuleSpec, module: Base.PyObject) -> (),
}

export type ModuleSpec = {
	name: string,
	origin: string,
	is_package: boolean,
	submodule_search_locations: { string }?,
	loader: Loader?,
	parent: string?,
}

-- Create a new ModuleSpec
function ModuleSpec.new(
	name: string,
	origin: string,
	is_package: boolean,
	submodule_search_locations: { string }?,
	loader: Loader?,
	parent: string?
): ModuleSpec
	return {
		name = name,
		origin = origin,
		is_package = is_package,
		submodule_search_locations = submodule_search_locations,
		loader = loader,
		parent = parent,
	}
end

-- Register the ModuleSpec type once at module load time
local moduleSpecType = Base.registerType("ModuleSpec", {
	bases = { Base.getTypeObject("object") },
})

-- Convert ModuleSpec to a Python object (for __spec__ attribute)
function ModuleSpec.toPyObject(spec: ModuleSpec): Base.PyObject
	-- Create a simple namespace-like object
	local specDict: { [string]: Base.PyObject } = {
		name = Base.newPyObject("str", spec.name),
		origin = Base.newPyObject("str", spec.origin),
		parent = if spec.parent then Base.newPyObject("str", spec.parent) else Base.newNone(),
		has_location = Base.newBool(spec.origin ~= "builtin"),
	}

	if spec.submodule_search_locations then
		local locations: { Base.PyObject } = {}
		for _, loc in ipairs(spec.submodule_search_locations) do
			table.insert(locations, Base.newPyObject("str", loc))
		end
		specDict.submodule_search_locations = Collections.newList(locations)
	else
		specDict.submodule_search_locations = Base.newNone()
	end

	-- Create the spec object with attributes in __dict
	local specObj: Base.PyObject = {
		__type = "ModuleSpec",
		__value = nil,
		__dict = specDict,
		__typeobj = moduleSpecType,
	}

	return specObj
end

return ModuleSpec
