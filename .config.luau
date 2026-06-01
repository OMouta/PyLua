return {
    project = {
        name = "PyLua",
        version = "0.3.0",
        description = "Embedded Python Interpreter for Luau",
        license = "MIT",
        authors = {
            "OMouta"
        },
    },
    luau = {
        languageMode = "strict",
        lint = {
            ["*"] = true,
            LocalUnused = false,
        },
        lintErrors = true,
        aliases = {
            std = "~/.lute/typedefs/1.0.0/std", 
            lute = "~/.lute/typedefs/1.0.0/lute", 
            lint = "~/.lute/typedefs/1.0.0/lint"
        },
    },
    tasks = {
        build = "rojo build default.project.json --output build/pylua.rbxm",
        format = "stylua src",
        lint = "lute lint src tests",
        typecheck = "lute check",
        test = "lute tests/run_tests.luau",
    },
    luu = {
        install = {
            tools = true,
        },
    },
}
