local tokens = require("../../tokens")
local nodes = require("../../ast/nodes")

export type Token = tokens.Token
export type Expr = nodes.Expr
export type Arguments = nodes.Arguments

local function prefixContains(prefix: string?, flag: string): boolean
	if not prefix then
		return false
	end
	return string.find(prefix, flag, 1, true) ~= nil
end

local function makeStringConstant(token: Token): Expr
	local prefix = (token :: any).stringPrefix
	local content = (token :: any).stringContent
	local value: string
	if content ~= nil then
		value = content
	else
		local v = token.value
		if
			#v >= 6
			and (
				(string.sub(v, 1, 3) == '"""' and string.sub(v, -3) == '"""')
				or (string.sub(v, 1, 3) == "'''" and string.sub(v, -3) == "'''")
			)
		then
			value = string.sub(v, 4, -4)
		elseif
			#v >= 2
			and (
				(string.sub(v, 1, 1) == '"' and string.sub(v, -1) == '"')
				or (string.sub(v, 1, 1) == "'" and string.sub(v, -1) == "'")
			)
		then
			value = string.sub(v, 2, -2)
		else
			value = v
		end
	end

	local outKind = prefix
	if outKind and string.find(outKind, "u", 1, true) then
		outKind = string.gsub(outKind, "u", "")
		if outKind == "" then
			outKind = nil
		end
	end
	local isBytes = outKind and string.find(outKind, "b", 1, true) ~= nil
	if isBytes then
		outKind = "bytes"
	end

	return {
		type = "Constant",
		value = value,
		kind = outKind,
		lineno = token.line,
		col_offset = token.column,
	}
end

local function makeNameNode(id: string, baseNode: Expr?, token: Token): Expr
	local lineno = if baseNode then baseNode.lineno else token.line
	local col = if baseNode then baseNode.col_offset else token.column
	return { type = "Name", id = id, ctx = "Load", lineno = lineno, col_offset = col }
end

local function wrapCall(funcName: string, argList: { Expr }, baseNode: Expr, token: Token): Expr
	local funcNode = makeNameNode(funcName, baseNode, token)
	return {
		type = "Call",
		func = funcNode,
		args = argList,
		keywords = {},
		lineno = baseNode.lineno,
		col_offset = baseNode.col_offset,
	}
end

local function foldConcat(parts: { Expr }, token: Token): Expr
	if #parts == 0 then
		return {
			type = "Constant",
			value = "",
			kind = nil,
			lineno = token.line,
			col_offset = token.column,
		}
	end
	local result: Expr = parts[1]
	for i = 2, #parts do
		result = {
			type = "BinOp",
			left = result,
			op = "Add",
			right = parts[i],
			lineno = token.line,
			col_offset = token.column,
		}
	end
	return result
end

local function newArguments(): nodes.Arguments
	return {
		posonlyargs = {},
		args = {},
		vararg = nil,
		kwonlyargs = {},
		kw_defaults = {},
		kwarg = nil,
		defaults = {},
	}
end

return {
	prefixContains = prefixContains,
	makeStringConstant = makeStringConstant,
	makeNameNode = makeNameNode,
	wrapCall = wrapCall,
	foldConcat = foldConcat,
	newArguments = newArguments,
}
