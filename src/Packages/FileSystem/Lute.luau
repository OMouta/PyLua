--!strict
-- Lute FileSystem Implementation
-- https://lute.luau.org/reference/lute/fs.html

local fs = require("@lute/fs")

local LuteFS = {}

function LuteFS.readFile(path: string): string?
	if fs.exists(path) and fs.type(path) == "file" then
		return fs.readfiletostring(path)
	end
	return nil
end

function LuteFS.exists(path: string): boolean
	return fs.exists(path)
end

function LuteFS.isDir(path: string): boolean
	return fs.exists(path) and fs.type(path) == "dir"
end

return LuteFS
