local TestFramework = require("../framework")
local PyLua = require("../../src/PyLua")

local pep451Tests = {
	name = "PEP 451 Import System",
	tests = {
		{
			name = "Memory mounts - single file module",
			test = function()
				local py = PyLua.new({
					mounts = {
						myapp = {
							["__init__.py"] = "",
							["utils.py"] = "def helper(): return 42",
						},
					},
				})

				py:execute([[
import myapp.utils
result = myapp.utils.helper()
]])
				TestFramework.assertEqual(py:getGlobal("result"), 42)
			end,
		},
		{
			name = "Memory mounts - package with __init__.py",
			test = function()
				local py = PyLua.new({
					mounts = {
						myapp = {
							["__init__.py"] = "version = '1.0.0'",
							["core/__init__.py"] = "name = 'core'",
							["core/processor.py"] = "def process(x): return x * 2",
						},
					},
				})

				py:execute([[
import myapp
import myapp.core
import myapp.core.processor

v = myapp.version
n = myapp.core.name
result = myapp.core.processor.process(10)
]])
				TestFramework.assertEqual(py:getGlobal("v"), "1.0.0")
				TestFramework.assertEqual(py:getGlobal("n"), "core")
				TestFramework.assertEqual(py:getGlobal("result"), 20)
			end,
		},
		{
			name = "Relative imports - sibling module",
			test = function()
				local py = PyLua.new({
					mounts = {
						pkg = {
							["__init__.py"] = "",
							["module_a.py"] = "x = 100",
							["module_b.py"] = [[
from .module_a import x
y = x + 1
]],
						},
					},
				})

				py:execute([[
import pkg.module_b
result = pkg.module_b.y
]])
				TestFramework.assertEqual(py:getGlobal("result"), 101)
			end,
		},
		{
			name = "Relative imports - parent package",
			test = function()
				local py = PyLua.new({
					mounts = {
						pkg = {
							["__init__.py"] = "shared = 'parent'",
							["sub/__init__.py"] = "",
							["sub/child.py"] = [[
from .. import shared
value = shared
]],
						},
					},
				})

				py:execute([[
import pkg.sub.child
result = pkg.sub.child.value
]])
				TestFramework.assertEqual(py:getGlobal("result"), "parent")
			end,
		},
		{
			name = "Policy - allow specific modules",
			test = function()
				local py = PyLua.new({
					mounts = {
						allowed = {
							["__init__.py"] = "",
							["module.py"] = "x = 1",
						},
						denied = {
							["__init__.py"] = "",
							["module.py"] = "x = 2",
						},
					},
					policy = {
						allow = { allowed = true },
					},
				})

				py:execute("import allowed.module")
				TestFramework.assertEqual(py:eval("allowed.module.x"), 1)

				TestFramework.assertError(function()
					py:execute("import denied.module")
					return false
				end, "ModuleNotFoundError")
			end,
		},
		{
			name = "Policy - deny specific modules",
			test = function()
				local py = PyLua.new({
					mounts = {
						safe = {
							["__init__.py"] = "",
							["module.py"] = "x = 1",
						},
						unsafe = {
							["__init__.py"] = "",
							["module.py"] = "x = 2",
						},
					},
					policy = {
						allow = { ["*"] = true },
						deny = { unsafe = true },
					},
				})

				py:execute("import safe.module")
				TestFramework.assertEqual(py:eval("safe.module.x"), 1)

				TestFramework.assertError(function()
					py:execute("import unsafe.module")
					return false
				end, "ModuleNotFoundError")
			end,
		},
		{
			name = "Module __spec__ attribute",
			test = function()
				local py = PyLua.new({
					mounts = {
						mymod = {
							["__init__.py"] = "",
							["test.py"] = "x = 1",
						},
					},
				})

				py:execute([[
import mymod.test
spec = mymod.test.__spec__
]])
				local spec = py:getGlobalPy("spec")
				-- __spec__ is a ModuleSpec object
				TestFramework.assertEqual(spec.__type, "ModuleSpec")

				local name = py:eval("mymod.test.__spec__.name")
				TestFramework.assertEqual(name, "mymod.test")

				local origin = py:eval("mymod.test.__spec__.origin")
				TestFramework.assertTrue(
					string.find(origin, "memory:/mymod/test.py") ~= nil,
					"origin should contain memory path"
				)
			end,
		},
		{
			name = "Package __path__ attribute",
			test = function()
				local py = PyLua.new({
					mounts = {
						pkg = {
							["__init__.py"] = "x = 1",
						},
					},
				})

				py:execute([[
import pkg
try:
    path_attr = pkg.__path__
    has_path = True
except AttributeError:
    has_path = False
]])
				TestFramework.assertTrue(py:getGlobal("has_path"), "Packages should have __path__")

				local path = py:eval("pkg.__path__")
				TestFramework.assertEqual(path.__type, "list")
			end,
		},
		{
			name = "Module __package__ attribute",
			test = function()
				local py = PyLua.new({
					mounts = {
						parent = {
							["__init__.py"] = "",
							["child.py"] = "x = 1",
						},
					},
				})

				py:execute([[
import parent.child
pkg = parent.child.__package__
]])
				TestFramework.assertEqual(py:getGlobal("pkg"), "parent")
			end,
		},
		{
			name = "Circular imports with memory mounts",
			test = function()
				local py = PyLua.new({
					mounts = {
						circular = {
							["__init__.py"] = "",
							["a.py"] = [[
import circular.b
x = 1
try:
    y = circular.b.y
except AttributeError:
    y = 0
]],
							["b.py"] = [[
import circular.a
y = 2
try:
    x = circular.a.x
except AttributeError:
    x = 0
]],
						},
					},
				})

				py:execute([[
import circular.a
import circular.b
]])
				-- Both should import without error
				TestFramework.assertEqual(py:eval("circular.a.x"), 1)
				TestFramework.assertEqual(py:eval("circular.b.y"), 2)
			end,
		},
		{
			name = "Mixed sources - native and memory",
			test = function()
				local py = PyLua.new({
					nativeModules = {
						native_mod = {
							value = 100,
						},
					},
					mounts = {
						mem_mod = {
							["__init__.py"] = [[
import native_mod
combined = native_mod.value + 50
]],
						},
					},
				})

				py:execute([[
import mem_mod
result = mem_mod.combined
]])
				TestFramework.assertEqual(py:getGlobal("result"), 150)
			end,
		},
		{
			name = "sys.modules caching",
			test = function()
				local py = PyLua.new({
					mounts = {
						cached = {
							["__init__.py"] = "",
							["module.py"] = "x = []",
						},
					},
				})

				py:execute([[
import cached.module
cached.module.x.append(1)

import cached.module as m2
# Should be the same object
cached.module.x.append(2)

result = m2.x
]])
				local result = py:getGlobal("result")
				TestFramework.assertEqual(#result, 2)
			end,
		},
	},
}

TestFramework.runSuite(pep451Tests)

return {}
