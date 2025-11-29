--!strict
-- Loaders: PEP 451-inspired module loaders
-- Responsible for creating and executing modules

local Base = require("../../objects/base")
local ModuleSpec = require("./specs")

local Loaders = {}

export type Loader = ModuleSpec.Loader

-- NativeLoader: Loads modules from native Luau objects
export type NativeLoader = Loader & {
	native_module: Base.PyObject,
}

function Loaders.newNativeLoader(nativeModule: Base.PyObject): NativeLoader
	return {
		native_module = nativeModule,
		create_module = nil, -- Use default module creation
		exec_module = function(_spec: ModuleSpec.ModuleSpec, module: Base.PyObject)
			-- Copy attributes from native module to the module being loaded
			local nativeDict = (nativeModule :: any).__dict
			local moduleDict = (module :: any).__dict
			if nativeDict and moduleDict then
				for key, value in pairs(nativeDict) do
					moduleDict[key] = value
				end
			end
		end,
	} :: any
end

-- SourceLoader: Loads modules from Python source code
export type SourceLoader = Loader & {
	source: string,
	filename: string,
	executor: (code: string, filename: string, globals: { [string]: Base.PyObject }) -> (),
}

function Loaders.newSourceLoader(
	source: string,
	filename: string,
	executor: (string, string, { [string]: Base.PyObject }) -> ()
): SourceLoader
	return {
		source = source,
		filename = filename,
		executor = executor,
		create_module = nil, -- Use default module creation
		exec_module = function(_spec: ModuleSpec.ModuleSpec, module: Base.PyObject)
			local moduleDict = (module :: any).__dict :: { [string]: Base.PyObject }
			executor(source, filename, moduleDict)
		end,
	} :: any
end

-- SysModuleLoader: Special loader for the 'sys' builtin module
export type SysModuleLoader = Loader & {
	sys_modules: any,
	sys_path: any,
}

function Loaders.newSysModuleLoader(sysModules: any, sysPath: any): SysModuleLoader
	return {
		sys_modules = sysModules,
		sys_path = sysPath,
		create_module = nil,
		exec_module = function(_spec: ModuleSpec.ModuleSpec, module: Base.PyObject)
			local dict = (module :: any).__dict :: { [string]: Base.PyObject }
			dict["modules"] = sysModules
			dict["path"] = sysPath
		end,
	} :: any
end

return Loaders
