--!strict
-- PEP 451-inspired import system for PyLua
-- Implements ModuleSpec, Finders, and Loaders architecture

local Base = require("../objects/base")
local Module = require("../objects/module")
local Collections = require("../objects/collections")
local ModuleSpec = require("@self/specs")
local Finders = require("@self/finders")

local ImportSystem = {}
ImportSystem.__index = ImportSystem

export type FileSystem = Finders.FileSystem
export type Policy = Finders.Policy

export type ImportSystem = {
	sys_modules: Collections.PyDict,
	sys_path: Collections.PyList,
	sys_meta_path: Collections.PyList,
	builtins: { [string]: Base.PyObject },
	finders: { Finders.Finder },
	executor: ((code: string, filename: string, globals: { [string]: Base.PyObject }) -> ())?,

	importModule: (
		self: ImportSystem,
		name: string,
		globals: any?,
		locals: any?,
		fromlist: any?,
		level: number?
	) -> Base.PyObject,

	setExecutor: (self: ImportSystem, executor: (string, string, { [string]: Base.PyObject }) -> ()) -> (),
}

export type ImportSystemConfig = {
	builtins: { [string]: Base.PyObject },
	searchPath: { string }?,
	nativeModules: { [string]: Base.PyObject }?,
	mounts: { [string]: { [string]: string } }?,
	fileSystem: FileSystem?,
	enableFilesystem: boolean?,
	policy: Policy?,
}

function ImportSystem.new(config: ImportSystemConfig): ImportSystem
	local self = setmetatable({}, ImportSystem)

	self.sys_modules = Collections.newDict(nil)
	self.builtins = config.builtins
	self.executor = nil
	self.finders = {} :: { Finders.Finder }

	-- Create sys.path
	local paths: { Base.PyObject } = {}
	if config.searchPath then
		for _, p in ipairs(config.searchPath) do
			table.insert(paths, Base.newPyObject("str", p))
		end
	end
	self.sys_path = Collections.newList(paths)

	-- Create sys.meta_path (list of finders)
	local metaPathList: { Base.PyObject } = {}

	-- 1. BuiltinFinder (always enabled)
	local builtinFinder =
		Finders.newBuiltinFinder(config.nativeModules or {}, self.sys_modules, self.sys_path, config.policy)
	table.insert(self.finders, builtinFinder)

	-- 2. MemoryFinder (if mounts provided)
	if config.mounts and next(config.mounts) then
		local memoryFinder = Finders.newMemoryFinder(config.mounts, function(...)
			if self.executor then
				return self.executor(...)
			end
			error("Executor not set", 2)
		end, config.policy)
		table.insert(self.finders, memoryFinder)
	end

	-- 3. PathFinder (if filesystem enabled)
	if config.enableFilesystem and config.fileSystem and config.searchPath then
		local pathFinder = Finders.newPathFinder(config.searchPath, config.fileSystem, function(...)
			if self.executor then
				return self.executor(...)
			end
			error("Executor not set", 2)
		end, config.policy)
		table.insert(self.finders, pathFinder)
	end

	self.sys_meta_path = Collections.newList(metaPathList)

	return (self :: any) :: ImportSystem
end

function ImportSystem:setExecutor(executor: (string, string, { [string]: Base.PyObject }) -> ())
	self.executor = executor
end

-- Resolve relative imports to absolute name
-- In Python:
--   level=1 means "from current package" (e.g., from .foo means pkg.foo when in pkg.bar)
--   level=2 means "from parent package" (e.g., from ..foo means parent.foo when in parent.child.bar)
local function resolveRelativeImport(name: string, packageName: string?, level: number): string
	if level == 0 then
		return name
	end

	if not packageName or packageName == "" then
		error("ImportError: attempted relative import with no known parent package", 0)
	end

	local parts = {}
	for part in string.gmatch(packageName, "[^.]+") do
		table.insert(parts, part)
	end

	-- Level 1 = current package (remove 0 parts)
	-- Level 2 = parent package (remove 1 part)
	-- etc.
	local levelsToRemove = level - 1
	for _ = 1, levelsToRemove do
		if #parts == 0 then
			error("ImportError: attempted relative import beyond top-level package", 0)
		end
		table.remove(parts)
	end

	-- If there's a module name, append it
	if name and name ~= "" then
		if #parts > 0 then
			return table.concat(parts, ".") .. "." .. name
		else
			return name
		end
	else
		if #parts > 0 then
			return table.concat(parts, ".")
		else
			error("ImportError: attempted relative import beyond top-level package", 0)
		end
	end
end

function ImportSystem:importModule(
	name: string,
	globals: any?,
	_locals: any?,
	fromlist: any?,
	level: number?
): Base.PyObject
	local importLevel = level or 0
	local actualName = name

	-- Handle relative imports
	if importLevel > 0 then
		local packageName: string? = nil
		if globals and type(globals) == "table" then
			local pkgObj = globals["__package__"]
			if pkgObj and pkgObj.__type == "str" then
				packageName = pkgObj.__value
			end
		end
		actualName = resolveRelativeImport(name, packageName, importLevel)
	end

	-- Parse name into parts for parent package handling
	local parts = {}
	for part in string.gmatch(actualName, "[^.]+") do
		table.insert(parts, part)
	end

	-- Ensure parent packages are imported first
	if #parts > 1 then
		-- Import all parent packages
		for i = 1, #parts - 1 do
			local parentName = table.concat(parts, ".", 1, i)
			local parentNameObj = Base.newPyObject("str", parentName)
			local modulesDict = self.sys_modules
			local getMethod = Base.getattr(modulesDict, "get")
			local existing = Base.call(getMethod, { parentNameObj })

			if existing.__type == "NoneType" then
				-- Recursively import the parent
				self:importModule(parentName, globals, nil, nil, 0)
			end
		end
	end

	-- Determine if we have a fromlist
	local hasFromlist = false
	if fromlist then
		if type(fromlist) == "table" then
			if fromlist.__type == "tuple" or fromlist.__type == "list" then
				local items = fromlist.__value
				hasFromlist = items and #items > 0
			elseif fromlist.__type ~= "NoneType" then
				hasFromlist = true
			end
		end
	end

	-- Check sys.modules cache
	local modulesDict = self.sys_modules
	local getMethod = Base.getattr(modulesDict, "get")
	local nameObj = Base.newPyObject("str", actualName)
	local existing = Base.call(getMethod, { nameObj })

	if existing.__type ~= "NoneType" then
		-- Module is already loaded, but we need to return the right module
		-- based on fromlist
		if not hasFromlist and #parts > 1 then
			-- Return the top-level package for "import a.b.c"
			local topLevelName = parts[1]
			local topLevelNameObj = Base.newPyObject("str", topLevelName)
			local topLevelMod = Base.call(Base.getattr(modulesDict, "get"), { topLevelNameObj })
			if topLevelMod and topLevelMod.__type ~= "NoneType" then
				return topLevelMod
			end
		end
		return existing
	end

	-- Try each finder in order
	local spec: ModuleSpec.ModuleSpec? = nil
	for _, finder in ipairs(self.finders) do
		spec = finder:find_spec(actualName, nil)
		if spec then
			break
		end
	end

	if not spec then
		error("ModuleNotFoundError: No module named '" .. actualName .. "'", 0)
	end

	-- Create the module object
	local mod: Base.PyObject
	if spec.loader and spec.loader.create_module then
		local created = spec.loader.create_module(spec)
		if created then
			mod = created
		else
			mod = Module.new(spec.name, nil)
		end
	else
		mod = Module.new(spec.name, nil)
	end

	-- Set module attributes from spec
	local dict = (mod :: any).__dict :: { [string]: Base.PyObject }
	dict["__name__"] = Base.newPyObject("str", spec.name)
	dict["__spec__"] = ModuleSpec.toPyObject(spec)
	dict["__loader__"] = Base.newNone() -- Could wrap the loader

	if spec.origin ~= "builtin" then
		dict["__file__"] = Base.newPyObject("str", spec.origin)
	end

	if spec.is_package then
		if spec.submodule_search_locations then
			local locations: { Base.PyObject } = {}
			for _, loc in ipairs(spec.submodule_search_locations) do
				table.insert(locations, Base.newPyObject("str", loc))
			end
			dict["__path__"] = Collections.newList(locations)
		end
		dict["__package__"] = Base.newPyObject("str", spec.name)
	else
		-- For modules, __package__ is the parent package name
		if spec.parent then
			dict["__package__"] = Base.newPyObject("str", spec.parent)
		else
			dict["__package__"] = Base.newNone()
		end
	end

	-- Add to sys.modules BEFORE exec_module (for circular imports)
	local setMethod = Base.getattr(modulesDict, "__setitem__")
	Base.call(setMethod, { nameObj, mod })

	-- Execute the module
	if spec.loader and spec.loader.exec_module then
		spec.loader.exec_module(spec, mod)
	end

	-- Bind submodule to parent package
	-- If this is a submodule (e.g., "pkg.sub.mod"), bind it to its parent
	if spec.parent then
		local parentNameObj = Base.newPyObject("str", spec.parent)
		-- Re-fetch parent from sys.modules to ensure we have the right reference
		local parentMod = Base.call(Base.getattr(modulesDict, "get"), { parentNameObj })

		if parentMod and parentMod.__type ~= "NoneType" then
			local parentDict = (parentMod :: any).__dict
			if parentDict then
				-- Get the last component of the name (e.g., "mod" from "pkg.sub.mod")
				local lastPart = string.match(spec.name, "%.([^.]+)$")
				if not lastPart then
					lastPart = spec.name
				end
				parentDict[lastPart] = mod
			end
		end
	end

	-- Determine what to return based on fromlist
	-- If fromlist is empty/None: return the top-level module (for "import a.b.c")
	-- If fromlist is non-empty: return the requested module (for "from a.b import c")
	if not hasFromlist and #parts > 1 then
		-- Return the top-level package
		local topLevelName = parts[1]
		local topLevelNameObj = Base.newPyObject("str", topLevelName)
		local topLevelMod = Base.call(Base.getattr(modulesDict, "get"), { topLevelNameObj })
		if topLevelMod and topLevelMod.__type ~= "NoneType" then
			return topLevelMod
		end
	end

	return mod
end

return ImportSystem
