--!strict
-- Virtual FileSystem (Memory-based)

local VirtualFS = {}

function VirtualFS.new(files: { [string]: string })
	return {
		readFile = function(path: string): string?
			return files[path]
		end,
		exists = function(path: string): boolean
			-- Check exact match
			if files[path] then
				return true
			end
			-- Check if it's a directory (prefix match)
			for k in pairs(files) do
				if string.sub(k, 1, #path) == path and string.sub(k, #path + 1, #path + 1) == "/" then
					return true
				end
			end
			return false
		end,
		isDir = function(path: string): boolean
			if files[path] then
				return false
			end
			for k in pairs(files) do
				if string.sub(k, 1, #path) == path and string.sub(k, #path + 1, #path + 1) == "/" then
					return true
				end
			end
			return false
		end,
	}
end

return VirtualFS
