local precedence = {}

-- Precedence levels (lower number = lower precedence)
precedence.LEVELS = {
	OR = 1,
	AND = 2,
	NOT = 3, -- unary not
	IN = 4,
	NOT_IN = 4,
	IS = 4,
	IS_NOT = 4,
	LESS = 4,
	LESSEQUAL = 4,
	GREATER = 4,
	GREATEREQUAL = 4,
	EQEQUAL = 4,
	NOTEQUAL = 4,
	VBAR = 5, -- bitwise or
	CIRCUMFLEX = 6, -- xor
	AMPER = 7, -- bitwise and
	LEFTSHIFT = 8,
	RIGHTSHIFT = 8,
	PLUS = 9,
	MINUS = 9,
	STAR = 10,
	SLASH = 10,
	DOUBLESLASH = 10,
	PERCENT = 10,
	AT = 10,
	UNARY = 11, -- unary + - ~ handled specially
	DOUBLESTAR = 12, -- exponentiation (right associative)
}

-- Binary operator token -> AST BinOpType
precedence.BINOP_MAP = {
	PLUS = "Add",
	MINUS = "Sub",
	STAR = "Mult",
	SLASH = "Div",
	DOUBLESLASH = "FloorDiv",
	PERCENT = "Mod",
	DOUBLESTAR = "Pow",
	LEFTSHIFT = "LShift",
	RIGHTSHIFT = "RShift",
	VBAR = "BitOr",
	CIRCUMFLEX = "BitXor",
	AMPER = "BitAnd",
	AT = "MatMult",
}

-- Augmented assignment mapping (token of operator before '=' -> BinOpType)
precedence.AUGASSIGN_MAP = precedence.BINOP_MAP

return precedence
