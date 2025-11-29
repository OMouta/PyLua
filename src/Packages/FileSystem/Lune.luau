--!strict
-- Lune FileSystem Implementation
-- https://lune-org.github.io/docs/api-reference/fs/

local fs = require("@lune/fs")

local LuneFS = {}

function LuneFS.readFile(path: string): string?
	if fs.isFile(path) then
		return fs.readFile(path)
	end
	return nil
end

function LuneFS.exists(path: string): boolean
	return fs.isFile(path) or fs.isDir(path)
end

function LuneFS.isDir(path: string): boolean
	return fs.isDir(path)
end

return LuneFS
