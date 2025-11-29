local Base = require("../objects/base")
local Module = require("../objects/module")
local Collections = require("../objects/collections")

local Importer = {}
Importer.__index = Importer

export type FileSystem = {
	readFile: (path: string) -> string?,
	exists: (path: string) -> boolean,
	isDir: (path: string) -> boolean,
}

export type Importer = {
	sys_modules: Collections.PyDict, -- The Python dict object
	sys_path: Collections.PyList,
	builtins: { [string]: Base.PyObject },
	native_modules: { [string]: Base.PyObject },
	file_system: FileSystem?,
	executor: ((code: string, filename: string, globals: { [string]: Base.PyObject }) -> ())?,
	importModule: (
		self: Importer,
		name: string,
		globals: any?,
		locals: any?,
		fromlist: any?,
		level: number?
	) -> Base.PyObject,
	setExecutor: (self: Importer, executor: (string, string, { [string]: Base.PyObject }) -> ()) -> (),
}

function Importer.new(
	builtins: { [string]: Base.PyObject },
	searchPath: { string }?,
	nativeModules: { [string]: Base.PyObject }?,
	fileSystem: FileSystem?
): Importer
	local self = setmetatable({}, Importer)
	self.sys_modules = Collections.newDict(nil)

	local paths: { Base.PyObject } = {}
	if searchPath then
		for _, p in ipairs(searchPath) do
			table.insert(paths, Base.newPyObject("str", p))
		end
	end
	self.sys_path = Collections.newList(paths)

	self.builtins = builtins
	self.native_modules = nativeModules or {}
	self.file_system = fileSystem
	self.executor = nil
	return (self :: any) :: Importer
end

function Importer:setExecutor(executor: (string, string, { [string]: Base.PyObject }) -> ())
	self.executor = executor
end

local function joinPath(p1: string, p2: string): string
	if string.sub(p1, -1) == "/" or string.sub(p1, -1) == "\\" then
		return p1 .. p2
	end
	return p1 .. "/" .. p2
end

function Importer:importModule(name: string, globals: any?, locals: any?, fromlist: any?, level: number?): Base.PyObject
	-- Check sys.modules
	local modulesDict = self.sys_modules
	local getMethod = Base.getattr(modulesDict, "get")
	local nameObj = Base.newPyObject("str", name)
	local existing = Base.call(getMethod, { nameObj })

	if existing.__type ~= "NoneType" then
		return existing
	end

	-- Check builtins (native modules)
	if name == "sys" then
		local sysMod = Module.new("sys", "System-specific parameters and functions")
		local sysDict = sysMod.__dict
		if not sysDict then
			sysDict = {}
			sysMod.__dict = sysDict
		end
		local dict = sysDict :: { [string]: Base.PyObject }
		dict["modules"] = self.sys_modules
		dict["path"] = self.sys_path

		-- Add to sys.modules
		local setMethod = Base.getattr(modulesDict, "__setitem__")
		Base.call(setMethod, { nameObj, sysMod })

		return sysMod
	end

	-- Check registered native modules
	if self.native_modules[name] then
		local mod = self.native_modules[name]
		local setMethod = Base.getattr(modulesDict, "__setitem__")
		Base.call(setMethod, { nameObj, mod })
		return mod
	end

	-- Check filesystem
	if self.file_system and self.executor then
		local fs = self.file_system
		local executor = self.executor
		local searchPaths = self.sys_path.__value :: { Base.PyObject }

		for _, pathObj in ipairs(searchPaths) do
			local path = pathObj.__value :: string

			-- Check for name.py
			local fileCandidate = joinPath(path, name .. ".py")
			if fs.exists(fileCandidate) and not fs.isDir(fileCandidate) then
				local source = fs.readFile(fileCandidate)
				if source then
					local mod = Module.new(name, nil)
					local dict = mod.__dict :: { [string]: Base.PyObject }
					dict["__file__"] = Base.newPyObject("str", fileCandidate)

					-- Add to sys.modules BEFORE execution to handle circular imports
					local setMethod = Base.getattr(modulesDict, "__setitem__")
					Base.call(setMethod, { nameObj, mod })

					executor(source, fileCandidate, dict)
					return mod
				end
			end

			-- Check for name/__init__.py (package)
			local pkgCandidate = joinPath(path, name)
			local initCandidate = joinPath(pkgCandidate, "__init__.py")
			if fs.exists(pkgCandidate) and fs.isDir(pkgCandidate) and fs.exists(initCandidate) then
				local source = fs.readFile(initCandidate)
				if source then
					local mod = Module.new(name, nil)
					local dict = mod.__dict :: { [string]: Base.PyObject }
					dict["__file__"] = Base.newPyObject("str", initCandidate)
					dict["__path__"] = Collections.newList({ Base.newPyObject("str", pkgCandidate) })
					dict["__package__"] = Base.newPyObject("str", name)

					-- Add to sys.modules BEFORE execution
					local setMethod = Base.getattr(modulesDict, "__setitem__")
					Base.call(setMethod, { nameObj, mod })

					executor(source, initCandidate, dict)
					return mod
				end
			end
		end
	end

	error("ModuleNotFoundError: No module named '" .. name .. "'", 0)
end

return Importer
