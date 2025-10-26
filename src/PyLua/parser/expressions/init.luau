-- This module handles expression parsing

local tokens = require("../tokens")
local nodes = require("../ast/nodes")
local precedence = require("./precedence")

local postfix = require("./postfix")
local lexer = require("../lexer")

local utils = require("@self/utils")

local fstringFactory = require("@self/fstring")
local lambdaFactory = require("@self/lambda")
local primaryFactory = require("@self/primary")

local binaryFactory = require("@self/binary")

export type Token = tokens.Token

export type TokenType = tokens.TokenType
export type Expr = nodes.Expr

local expressions = {}

local parseBinaryExpression: (state: any, minPrec: number) -> Expr

local function parseExpression(state: any): Expr
	return parseBinaryExpression(state, precedence.LAMBDA)
end

local fstringModule = fstringFactory.new({
	lexer = lexer,
	wrapCall = utils.wrapCall,

	foldConcat = utils.foldConcat,
	parseExpression = parseExpression,
})

local primaryModule = primaryFactory.new({
	postfix = postfix,
	prefixContains = utils.prefixContains,

	makeStringConstant = utils.makeStringConstant,
	foldConcat = utils.foldConcat,
	parseExpression = parseExpression,

	parseFStringLiteral = fstringModule.parseFStringLiteral,
})

local parsePrimary = primaryModule.parsePrimary

local lambdaModule = lambdaFactory.new({
	precedence = precedence,
	postfix = postfix,

	parseBinaryExpression = function(state: any, minPrec: number)
		return parseBinaryExpression(state, minPrec)
	end,

	parseExpression = parseExpression,
	newArguments = utils.newArguments,
})

local parseLambda = lambdaModule.parseLambda

local binaryModule = binaryFactory.new({
	precedence = precedence,

	parsePrimary = parsePrimary,
	parseLambda = parseLambda,
})

parseBinaryExpression = binaryModule.parseBinaryExpression

function expressions.parse(state: any): Expr
	return parseExpression(state)
end

function expressions.parsePrimaryForTarget(state: any)
	return primaryModule.parsePrimaryForTarget(state)
end

return expressions
