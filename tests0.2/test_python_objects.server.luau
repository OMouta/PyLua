-- Test script for PyLua 0.2 Python Object System
-- Tests Python lists, dictionaries, tuples, sets, and their methods

local BytecodeExecutor = require('../src/PyLua0.2/vm/bytecode_executor')

local function testPythonLists()
    print("=== Testing Python Lists ===")
    
    -- Python equivalent:
    -- my_list = [1, 2, 3]
    -- my_list.append(4)
    -- length = len(my_list)
    -- first_item = my_list[0]
    -- my_list[1] = 99
    
    local bytecode = {        constants = {
            1,    -- 0
            2,    -- 1
            3,    -- 2
            4,    -- 3
            0,    -- 4 (index for first_item)
            1,    -- 5 (index for assignment)
            99,   -- 6 (new value)
        },
        names = {
            "my_list",     -- 0
            "append",      -- 1
            "len",         -- 2
            "length",      -- 3
            "first_item",  -- 4
        },
        code = {
            -- my_list = [1, 2, 3]
            {op="LOAD_CONST", arg=0, line=1},     -- Load 1
            {op="LOAD_CONST", arg=1, line=1},     -- Load 2
            {op="LOAD_CONST", arg=2, line=1},     -- Load 3
            {op="BUILD_LIST", arg=3, line=1},     -- Create list with 3 items
            {op="STORE_NAME", arg=0, line=1},     -- Store in my_list
            
            -- my_list.append(4)
            {op="LOAD_NAME", arg=0, line=2},      -- Load my_list
            {op="LOAD_ATTR", arg=1, line=2},      -- Load append method
            {op="LOAD_CONST", arg=3, line=2},     -- Load 4
            {op="CALL_FUNCTION", arg=1, line=2},  -- Call append(4)
            {op="POP_TOP", line=2},               -- Pop None result
            
            -- length = len(my_list)
            {op="LOAD_NAME", arg=2, line=3},      -- Load len function
            {op="LOAD_NAME", arg=0, line=3},      -- Load my_list
            {op="CALL_FUNCTION", arg=1, line=3},  -- Call len(my_list)
            {op="STORE_NAME", arg=3, line=3},     -- Store in length
            
            -- first_item = my_list[0]
            {op="LOAD_NAME", arg=0, line=4},      -- Load my_list
            {op="LOAD_CONST", arg=4, line=4},     -- Load 0 (index)
            {op="BINARY_SUBSCR", line=4},         -- my_list[0]
            {op="STORE_NAME", arg=4, line=4},     -- Store in first_item
              -- my_list[1] = 99
            {op="LOAD_NAME", arg=0, line=5},      -- Load my_list
            {op="LOAD_CONST", arg=5, line=5},     -- Load 1 (index)
            {op="LOAD_CONST", arg=6, line=5},     -- Load 99 (value)
            {op="STORE_SUBSCR", line=5},          -- my_list[1] = 99
        },
        sourceLines = {
            [1] = "my_list = [1, 2, 3]",
            [2] = "my_list.append(4)",
            [3] = "length = len(my_list)",
            [4] = "first_item = my_list[0]",
            [5] = "my_list[1] = 99"
        }
    }
    
    local returnValue, variables = BytecodeExecutor.execute(bytecode)
    
    print("Variables after execution:")
    for name, value in pairs(variables) do
        if name == "my_list" and type(value) == "table" and value.__type == "list" then
            print("  " .. name .. " = [" .. table.concat(value.__value, ", ") .. "]")
        else
            print("  " .. name .. " = " .. tostring(value))
        end
    end
    
    -- Verify results
    local my_list = variables.my_list
    assert(my_list.__type == "list", "my_list should be a Python list")
    assert(#my_list.__value == 4, "List should have 4 items after append")
    assert(my_list.__value[1] == 1, "First item should be 1")
    assert(my_list.__value[2] == 99, "Second item should be 99 after assignment")
    assert(my_list.__value[4] == 4, "Fourth item should be 4 after append")
    assert(variables.length == 4, "Length should be 4")
    assert(variables.first_item == 1, "First item should be 1")
    
    print("✓ Python lists test passed!")
end

local function testPythonDictionaries()
    print("\n=== Testing Python Dictionaries ===")
    
    -- Python equivalent:
    -- my_dict = {"name": "Python", "version": 3.8}
    -- my_dict["year"] = 2020
    -- name = my_dict["name"]
    -- keys = my_dict.keys()
    
    local bytecode = {
        constants = {
            "name",      -- 0
            "Python",    -- 1
            "version",   -- 2
            3.8,         -- 3
            "year",      -- 4
            2020,        -- 5
        },
        names = {
            "my_dict",   -- 0
            "name",      -- 1
            "keys",      -- 2
        },
        code = {
            -- my_dict = {"name": "Python", "version": 3.8}
            {op="LOAD_CONST", arg=0, line=1},     -- Load "name"
            {op="LOAD_CONST", arg=1, line=1},     -- Load "Python"
            {op="LOAD_CONST", arg=2, line=1},     -- Load "version"
            {op="LOAD_CONST", arg=3, line=1},     -- Load 3.8
            {op="BUILD_DICT", arg=2, line=1},     -- Create dict with 2 pairs
            {op="STORE_NAME", arg=0, line=1},     -- Store in my_dict
            
            -- my_dict["year"] = 2020
            {op="LOAD_NAME", arg=0, line=2},      -- Load my_dict
            {op="LOAD_CONST", arg=4, line=2},     -- Load "year"
            {op="LOAD_CONST", arg=5, line=2},     -- Load 2020
            {op="STORE_SUBSCR", line=2},          -- my_dict["year"] = 2020
            
            -- name = my_dict["name"]
            {op="LOAD_NAME", arg=0, line=3},      -- Load my_dict
            {op="LOAD_CONST", arg=0, line=3},     -- Load "name"
            {op="BINARY_SUBSCR", line=3},         -- my_dict["name"]
            {op="STORE_NAME", arg=1, line=3},     -- Store in name
            
            -- keys = my_dict.keys()
            {op="LOAD_NAME", arg=0, line=4},      -- Load my_dict
            {op="LOAD_ATTR", arg=2, line=4},      -- Load keys method
            {op="CALL_FUNCTION", arg=0, line=4},  -- Call keys()
            {op="STORE_NAME", arg=2, line=4},     -- Store in keys
        },
        sourceLines = {
            [1] = 'my_dict = {"name": "Python", "version": 3.8}',
            [2] = 'my_dict["year"] = 2020',
            [3] = 'name = my_dict["name"]',
            [4] = 'keys = my_dict.keys()'
        }
    }
    
    local returnValue, variables = BytecodeExecutor.execute(bytecode)
      print("Variables after execution:")
    for name, value in pairs(variables) do
        if name == "my_dict" and type(value) == "table" and value.__type == "dict" then
            print("  " .. name .. " = {dict with ? items}")
        elseif name == "keys" and type(value) == "table" and value.__type == "list" then
            print("  " .. name .. " = [list of keys]")
        else
            print("  " .. name .. " = " .. tostring(value))
        end
    end
      -- Verify results
    local my_dict = variables.my_dict
    print("DEBUG: my_dict type:", type(my_dict))
    if my_dict then
        print("DEBUG: my_dict.__type:", my_dict.__type)
        if my_dict.__value then
            print("DEBUG: my_dict.__value keys:")
            for k, v in pairs(my_dict.__value) do
                print("  ", k, "=", v)
            end
        end
    end
    
    assert(my_dict ~= nil, "my_dict should not be nil")
    assert(my_dict.__type == "dict", "my_dict should be a Python dict")
    assert(my_dict.__value["name"] == "Python", "Dict should contain name: Python")
    assert(my_dict.__value["version"] == 3.8, "Dict should contain version: 3.8")
    assert(my_dict.__value["year"] == 2020, "Dict should contain year: 2020 after assignment")
    assert(variables.name == "Python", "Name variable should be Python")
    
    local keys = variables.keys
    assert(keys.__type == "list", "Keys should be a Python list")
    assert(#keys.__value == 3, "Should have 3 keys")
    
    print("✓ Python dictionaries test passed!")
end

local function testPythonTuples()
    print("\n=== Testing Python Tuples ===")
    
    -- Python equivalent:
    -- my_tuple = (1, 2, 3)
    -- second_item = my_tuple[1]
    -- tuple_length = len(my_tuple)
    
    local bytecode = {
        constants = {
            1,    -- 0
            2,    -- 1
            3,    -- 2
            1,    -- 3 (index)
        },
        names = {
            "my_tuple",      -- 0
            "second_item",   -- 1
            "len",           -- 2
            "tuple_length",  -- 3
        },
        code = {
            -- my_tuple = (1, 2, 3)
            {op="LOAD_CONST", arg=0, line=1},     -- Load 1
            {op="LOAD_CONST", arg=1, line=1},     -- Load 2
            {op="LOAD_CONST", arg=2, line=1},     -- Load 3
            {op="BUILD_TUPLE", arg=3, line=1},    -- Create tuple with 3 items
            {op="STORE_NAME", arg=0, line=1},     -- Store in my_tuple
            
            -- second_item = my_tuple[1]
            {op="LOAD_NAME", arg=0, line=2},      -- Load my_tuple
            {op="LOAD_CONST", arg=3, line=2},     -- Load 1 (index)
            {op="BINARY_SUBSCR", line=2},         -- my_tuple[1]
            {op="STORE_NAME", arg=1, line=2},     -- Store in second_item
            
            -- tuple_length = len(my_tuple)
            {op="LOAD_NAME", arg=2, line=3},      -- Load len function
            {op="LOAD_NAME", arg=0, line=3},      -- Load my_tuple
            {op="CALL_FUNCTION", arg=1, line=3},  -- Call len(my_tuple)
            {op="STORE_NAME", arg=3, line=3},     -- Store in tuple_length
        },
        sourceLines = {
            [1] = "my_tuple = (1, 2, 3)",
            [2] = "second_item = my_tuple[1]",
            [3] = "tuple_length = len(my_tuple)"
        }
    }
    
    local returnValue, variables = BytecodeExecutor.execute(bytecode)
    
    print("Variables after execution:")
    for name, value in pairs(variables) do
        if name == "my_tuple" and type(value) == "table" and value.__type == "tuple" then
            print("  " .. name .. " = (" .. table.concat(value.__value, ", ") .. ")")
        else
            print("  " .. name .. " = " .. tostring(value))
        end
    end
    
    -- Verify results
    local my_tuple = variables.my_tuple
    assert(my_tuple.__type == "tuple", "my_tuple should be a Python tuple")
    assert(#my_tuple.__value == 3, "Tuple should have 3 items")
    assert(my_tuple.__value[2] == 2, "Second item should be 2")
    assert(variables.second_item == 2, "second_item should be 2")
    assert(variables.tuple_length == 3, "tuple_length should be 3")
    
    print("✓ Python tuples test passed!")
end

local function testPythonSets()
    print("\n=== Testing Python Sets ===")
    
    -- Python equivalent:
    -- my_set = {1, 2, 3}
    -- my_set.add(4)
    -- set_length = len(my_set)
    
    local bytecode = {
        constants = {
            1,    -- 0
            2,    -- 1
            3,    -- 2
            4,    -- 3
        },
        names = {
            "my_set",      -- 0
            "add",         -- 1
            "len",         -- 2
            "set_length",  -- 3
        },
        code = {
            -- my_set = {1, 2, 3}
            {op="LOAD_CONST", arg=0, line=1},     -- Load 1
            {op="LOAD_CONST", arg=1, line=1},     -- Load 2
            {op="LOAD_CONST", arg=2, line=1},     -- Load 3
            {op="BUILD_SET", arg=3, line=1},      -- Create set with 3 items
            {op="STORE_NAME", arg=0, line=1},     -- Store in my_set
            
            -- my_set.add(4)
            {op="LOAD_NAME", arg=0, line=2},      -- Load my_set
            {op="LOAD_ATTR", arg=1, line=2},      -- Load add method
            {op="LOAD_CONST", arg=3, line=2},     -- Load 4
            {op="CALL_FUNCTION", arg=1, line=2},  -- Call add(4)
            {op="POP_TOP", line=2},               -- Pop None result
            
            -- set_length = len(my_set)
            {op="LOAD_NAME", arg=2, line=3},      -- Load len function
            {op="LOAD_NAME", arg=0, line=3},      -- Load my_set
            {op="CALL_FUNCTION", arg=1, line=3},  -- Call len(my_set)
            {op="STORE_NAME", arg=3, line=3},     -- Store in set_length
        },
        sourceLines = {
            [1] = "my_set = {1, 2, 3}",
            [2] = "my_set.add(4)",
            [3] = "set_length = len(my_set)"
        }
    }
    
    local returnValue, variables = BytecodeExecutor.execute(bytecode)
    
    print("Variables after execution:")
    for name, value in pairs(variables) do
        if name == "my_set" and type(value) == "table" and value.__type == "set" then
            local items = {}
            for k, _ in pairs(value.__value) do
                table.insert(items, tostring(k))
            end
            print("  " .. name .. " = {" .. table.concat(items, ", ") .. "}")
        else
            print("  " .. name .. " = " .. tostring(value))
        end
    end
    
    -- Verify results
    local my_set = variables.my_set
    assert(my_set.__type == "set", "my_set should be a Python set")
    assert(my_set.__value[1] == true, "Set should contain 1")
    assert(my_set.__value[2] == true, "Set should contain 2")
    assert(my_set.__value[3] == true, "Set should contain 3")
    assert(my_set.__value[4] == true, "Set should contain 4 after add")
    assert(variables.set_length == 4, "set_length should be 4")
    
    print("✓ Python sets test passed!")
end

local function testMethodChaining()
    print("\n=== Testing Method Chaining ===")
    
    -- Python equivalent:
    -- numbers = [3, 1, 4, 1, 5]
    -- numbers.sort()
    -- numbers.reverse()
    -- first = numbers[0]
    
    local bytecode = {
        constants = {
            3,    -- 0
            1,    -- 1
            4,    -- 2
            1,    -- 3
            5,    -- 4
            0,    -- 5 (index)
        },
        names = {
            "numbers",   -- 0
            "sort",      -- 1
            "reverse",   -- 2
            "first",     -- 3
        },
        code = {
            -- numbers = [3, 1, 4, 1, 5]
            {op="LOAD_CONST", arg=0, line=1},     -- Load 3
            {op="LOAD_CONST", arg=1, line=1},     -- Load 1
            {op="LOAD_CONST", arg=2, line=1},     -- Load 4
            {op="LOAD_CONST", arg=3, line=1},     -- Load 1
            {op="LOAD_CONST", arg=4, line=1},     -- Load 5
            {op="BUILD_LIST", arg=5, line=1},     -- Create list
            {op="STORE_NAME", arg=0, line=1},     -- Store in numbers
            
            -- numbers.sort()
            {op="LOAD_NAME", arg=0, line=2},      -- Load numbers
            {op="LOAD_ATTR", arg=1, line=2},      -- Load sort method
            {op="CALL_FUNCTION", arg=0, line=2},  -- Call sort()
            {op="POP_TOP", line=2},               -- Pop None result
            
            -- numbers.reverse()
            {op="LOAD_NAME", arg=0, line=3},      -- Load numbers
            {op="LOAD_ATTR", arg=2, line=3},      -- Load reverse method
            {op="CALL_FUNCTION", arg=0, line=3},  -- Call reverse()
            {op="POP_TOP", line=3},               -- Pop None result
            
            -- first = numbers[0]
            {op="LOAD_NAME", arg=0, line=4},      -- Load numbers
            {op="LOAD_CONST", arg=5, line=4},     -- Load 0
            {op="BINARY_SUBSCR", line=4},         -- numbers[0]
            {op="STORE_NAME", arg=3, line=4},     -- Store in first
        },
        sourceLines = {
            [1] = "numbers = [3, 1, 4, 1, 5]",
            [2] = "numbers.sort()",
            [3] = "numbers.reverse()",
            [4] = "first = numbers[0]"
        }
    }
    
    local returnValue, variables = BytecodeExecutor.execute(bytecode)
    
    print("Variables after execution:")
    for name, value in pairs(variables) do
        if name == "numbers" and type(value) == "table" and value.__type == "list" then
            print("  " .. name .. " = [" .. table.concat(value.__value, ", ") .. "]")
        else
            print("  " .. name .. " = " .. tostring(value))
        end
    end
    
    -- Verify results
    local numbers = variables.numbers
    assert(numbers.__type == "list", "numbers should be a Python list")
    -- After sort: [1, 1, 3, 4, 5], after reverse: [5, 4, 3, 1, 1]
    assert(numbers.__value[1] == 5, "First item should be 5 after sort and reverse")
    assert(variables.first == 5, "first should be 5")
    
    print("✓ Method chaining test passed!")
end

-- Run all tests
local function runObjectTests()
    print("Starting PyLua 0.2 Python Object System Tests...")
    
    local tests = {
        {name = "Python Lists", fn = testPythonLists},
        {name = "Python Dictionaries", fn = testPythonDictionaries},
        {name = "Python Tuples", fn = testPythonTuples},
        {name = "Python Sets", fn = testPythonSets},
        {name = "Method Chaining", fn = testMethodChaining},
    }
    
    local passed = 0
    local failed = 0
    
    for _, test in ipairs(tests) do
        local success, error = pcall(test.fn)
        if success then
            passed = passed + 1
        else
            print("❌ " .. test.name .. " test failed: " .. tostring(error))
            failed = failed + 1
        end
    end
    
    print(string.format("\n🎉 Object System Tests Summary: %d passed, %d failed", passed, failed))
    
    if failed == 0 then
        print("All Python object system tests passed! 🐍✨")
    end
end

-- Execute tests
runObjectTests()
