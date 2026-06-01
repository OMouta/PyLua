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
    tasks = {
        build = "rojo build default.project.json --output build/pylua.rbxm",
        format = "stylua src",
        lint = "selene src",
        test = "lute tests/run_tests.luau",
    },
    luu = {
        install = {
            tools = true,
        },
    },
}
