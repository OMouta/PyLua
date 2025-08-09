--!strict
-- PyLua Compiler - AST to Bytecode compilation
-- Phase 4 - Will implement AST to bytecode transformation

local Compiler = {}

-- Placeholder types
export type Bytecode = {
	instructions: { any },
	constants: { any },
	names: { string },
}

-- Compile AST to bytecode
function Compiler.compile(ast: any): Bytecode
	-- TODO: Implement compiler in Phase 4
	error("Compiler not implemented yet - Phase 4", 2)
end

return Compiler
