local PyLua = require("../../src/PyLua")
local FileSystem = require("../../src/Packages/FileSystem/Virtual")

-- 1. Define a native module (Luau table)
local myMathModule = {
    add = function(a:number, b:number) return a + b end,
    PI = 3.14159
}

-- 2. Define a virtual filesystem (mocking real files)
local files = {
    ["/lib/utils.py"] = [[
def greet(name):
    return "Hello, " + name + "!"
]],
    ["/lib/pkg/__init__.py"] = "version = '1.0.0'"
}

-- 3. Initialize PyLua with these options
local py = PyLua.new({
    nativeModules = {
        ["my_math"] = myMathModule
    },
    fileSystem = FileSystem.new(files),
    searchPath = {"/lib"}
})

-- 4. Use them in Python
py:execute([[
import my_math
import utils
import pkg

print("Native module:", my_math.add(10, 20))
print("FS module:", utils.greet("User"))
print("Package version:", pkg.version)
]])
