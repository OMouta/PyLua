--!strict
-- Finders: PEP 451-inspired module finders
-- Responsible for locating modules and creating ModuleSpecs

local Base = require("../../objects/base")
local ModuleSpec = require("./specs")
local Loaders = require("./loaders")

local Finders = {}

export type Finder = {
	find_spec: (self: Finder, fullname: string, path: { string }?) -> ModuleSpec.ModuleSpec?,
}

-- BuiltinFinder: Finds builtin/native modules
export type BuiltinFinder = Finder & {
	native_modules: { [string]: Base.PyObject },
	sys_modules: any,
	sys_path: any,
	policy: Policy?,
}

export type Policy = {
	allow: { [string]: boolean }?,
	deny: { [string]: boolean }?,
}

function Finders.newBuiltinFinder(
	nativeModules: { [string]: Base.PyObject },
	sysModules: any,
	sysPath: any,
	policy: Policy?
): BuiltinFinder
	local self: BuiltinFinder = {
		native_modules = nativeModules,
		sys_modules = sysModules,
		sys_path = sysPath,
		policy = policy,
		find_spec = function(finder: Finder, fullname: string, _path: { string }?): ModuleSpec.ModuleSpec?
			local builtin = (finder :: any) :: BuiltinFinder

			-- Check policy
			if builtin.policy then
				if builtin.policy.deny and builtin.policy.deny[fullname] then
					return nil
				end
				if builtin.policy.allow and not builtin.policy.allow[fullname] and not builtin.policy.allow["*"] then
					return nil
				end
			end

			-- Special case: sys module
			if fullname == "sys" then
				local loader = Loaders.newSysModuleLoader(builtin.sys_modules, builtin.sys_path)
				return ModuleSpec.new("sys", "builtin", false, nil, loader, nil)
			end

			-- Check native modules
			if builtin.native_modules[fullname] then
				local nativeModule = builtin.native_modules[fullname]
				local loader = Loaders.newNativeLoader(nativeModule)
				return ModuleSpec.new(fullname, "builtin", false, nil, loader, nil)
			end

			return nil
		end,
	}
	return self
end

-- MemoryFinder: Finds modules from in-memory mounted trees
export type MemoryFinder = Finder & {
	mounts: { [string]: { [string]: string } },
	executor: (code: string, filename: string, globals: { [string]: Base.PyObject }) -> (),
	policy: Policy?,
}

function Finders.newMemoryFinder(
	mounts: { [string]: { [string]: string } },
	executor: (code: string, filename: string, globals: { [string]: Base.PyObject }) -> (),
	policy: Policy?
): MemoryFinder
	local self: MemoryFinder = {
		mounts = mounts,
		executor = executor,
		policy = policy,
		find_spec = function(finder: Finder, fullname: string, _path: { string }?): ModuleSpec.ModuleSpec?
			local memory = (finder :: any) :: MemoryFinder

			-- Check policy
			if memory.policy then
				local topLevel = string.match(fullname, "^([^.]+)")
				if topLevel and memory.policy.deny and memory.policy.deny[topLevel] then
					return nil
				end
				if
					topLevel
					and memory.policy.allow
					and not memory.policy.allow[topLevel]
					and not memory.policy.allow["*"]
				then
					return nil
				end
			end

			-- Parse the module name into parts
			local parts = {}
			for part in string.gmatch(fullname, "[^.]+") do
				table.insert(parts, part)
			end

			local topLevel: string? = parts[1]
			if not topLevel or not memory.mounts[topLevel] then
				return nil
			end

			-- After the check above, topLevel is guaranteed to be non-nil
			local topLevelName: string = topLevel :: string
			local mount = memory.mounts[topLevelName]

			-- Build the path within the mount (excluding the top-level package name)
			local pathParts = {}
			for i = 2, #parts do
				table.insert(pathParts, parts[i])
			end
			local path = table.concat(pathParts, "/")

			-- For top-level package itself (e.g., "myapp"), check __init__.py
			if #parts == 1 then
				if mount["__init__.py"] then
					local source = mount["__init__.py"]
					local origin = "memory:/" .. topLevelName .. "/__init__.py"
					local loader = Loaders.newSourceLoader(source, origin, memory.executor)
					return ModuleSpec.new(fullname, origin, true, { "memory:/" .. topLevelName }, loader, nil)
				end
				return nil
			end

			-- Check for module file: path.py
			local moduleFile = path .. ".py"
			if mount[moduleFile] then
				local source = mount[moduleFile]
				local origin = "memory:/" .. topLevelName .. "/" .. moduleFile
				local loader = Loaders.newSourceLoader(source, origin, memory.executor)
				return ModuleSpec.new(
					fullname,
					origin,
					false,
					nil,
					loader,
					if #parts > 1 then table.concat(parts, ".", 1, #parts - 1) else nil
				)
			end

			-- Check for package: path/__init__.py
			local initFile = path .. "/__init__.py"
			if mount[initFile] then
				local source = mount[initFile]
				local origin = "memory:/" .. topLevelName .. "/" .. initFile
				local loader = Loaders.newSourceLoader(source, origin, memory.executor)
				local pkgPath = "memory:/" .. topLevelName .. "/" .. path
				return ModuleSpec.new(
					fullname,
					origin,
					true,
					{ pkgPath },
					loader,
					if #parts > 1 then table.concat(parts, ".", 1, #parts - 1) else nil
				)
			end

			return nil
		end,
	}
	return self
end

-- PathFinder: Finds modules from filesystem via sys.path
export type FileSystem = {
	readFile: (path: string) -> string?,
	exists: (path: string) -> boolean,
	isDir: (path: string) -> boolean,
}

export type PathFinder = Finder & {
	search_path: { string },
	file_system: FileSystem,
	executor: (code: string, filename: string, globals: { [string]: Base.PyObject }) -> (),
	policy: Policy?,
}

function Finders.newPathFinder(
	searchPath: { string },
	fileSystem: FileSystem,
	executor: (code: string, filename: string, globals: { [string]: Base.PyObject }) -> (),
	policy: Policy?
): PathFinder
	local self: PathFinder = {
		search_path = searchPath,
		file_system = fileSystem,
		executor = executor,
		policy = policy,
		find_spec = function(finder: Finder, fullname: string, _path: { string }?): ModuleSpec.ModuleSpec?
			local pathFinder = (finder :: any) :: PathFinder
			local fs = pathFinder.file_system

			-- Check policy
			if pathFinder.policy then
				local topLevel: string? = string.match(fullname, "^([^.]+)")
				if topLevel then
					if pathFinder.policy.deny and pathFinder.policy.deny[topLevel] then
						return nil
					end
					if
						pathFinder.policy.allow
						and not pathFinder.policy.allow[topLevel]
						and not pathFinder.policy.allow["*"]
					then
						return nil
					end
				end
			end

			-- Convert dotted name to path
			local modulePath = string.gsub(fullname, "%.", "/")

			for _, searchDir in ipairs(pathFinder.search_path) do
				local function joinPath(p1: string, p2: string): string
					if string.sub(p1, -1) == "/" or string.sub(p1, -1) == "\\" then
						return p1 .. p2
					end
					return p1 .. "/" .. p2
				end

				-- Check for module file: path/to/module.py
				local moduleFile = joinPath(searchDir, modulePath .. ".py")
				if fs.exists(moduleFile) and not fs.isDir(moduleFile) then
					local source = fs.readFile(moduleFile)
					if source then
						local loader = Loaders.newSourceLoader(source, moduleFile, pathFinder.executor)
						local parts = {}
						for part in string.gmatch(fullname, "[^.]+") do
							table.insert(parts, part)
						end
						return ModuleSpec.new(
							fullname,
							"fs:" .. moduleFile,
							false,
							nil,
							loader,
							if #parts > 1 then table.concat(parts, ".", 1, #parts - 1) else nil
						)
					end
				end

				-- Check for package: path/to/package/__init__.py
				local pkgDir = joinPath(searchDir, modulePath)
				local initFile = joinPath(pkgDir, "__init__.py")
				if fs.exists(pkgDir) and fs.isDir(pkgDir) and fs.exists(initFile) then
					local source = fs.readFile(initFile)
					if source then
						local loader = Loaders.newSourceLoader(source, initFile, pathFinder.executor)
						local parts = {}
						for part in string.gmatch(fullname, "[^.]+") do
							table.insert(parts, part)
						end
						return ModuleSpec.new(
							fullname,
							"fs:" .. initFile,
							true,
							{ pkgDir },
							loader,
							if #parts > 1 then table.concat(parts, ".", 1, #parts - 1) else nil
						)
					end
				end
			end

			return nil
		end,
	}
	return self
end

return Finders
