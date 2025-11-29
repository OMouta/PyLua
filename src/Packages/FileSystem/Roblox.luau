--!strict
-- Roblox FileSystem (Instance-based)

local RobloxFS = {}

function RobloxFS.new(root: any)
	local function resolve(path: string): any
		local current = root
		-- Normalize path
		path = string.gsub(path, "\\", "/")
		-- Remove leading slash if present, as we start from root
		if string.sub(path, 1, 1) == "/" then
			path = string.sub(path, 2)
		end

		if path == "" then
			return current
		end

		for part in string.gmatch(path, "[^/]+") do
			if not current or typeof(current) ~= "Instance" then
				return nil
			end

			local nextChild = current:FindFirstChild(part)
			if not nextChild then
				-- Try removing extension if it has one (e.g. foo.py -> foo)
				local nameWithoutExt = string.match(part, "^(.+)%.[^%.]+$")
				if nameWithoutExt then
					nextChild = current:FindFirstChild(nameWithoutExt)
				end
			end

			if nextChild then
				current = nextChild
			else
				return nil
			end
		end
		return current
	end

	return {
		readFile = function(path: string): string?
			local inst = resolve(path)
			if inst then
				if inst:IsA("ModuleScript") then
					return inst.Source
				elseif inst:IsA("StringValue") then
					return inst.Value
				end
			end
			return nil
		end,
		exists = function(path: string): boolean
			return resolve(path) ~= nil
		end,
		isDir = function(path: string): boolean
			local inst = resolve(path)
			-- In Roblox, folders or anything with children can be a dir
			return inst ~= nil and #inst:GetChildren() > 0
		end,
	}
end

return RobloxFS
