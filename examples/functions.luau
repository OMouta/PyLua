local PyLua = require("../src/PyLua")
local python = PyLua.new()

python:execute([[ 
def add(a, b):
    return a + b

def greet(name):
    return "Hello, " + name

print("add(2, 3) =", add(2, 3))
print(greet("World"))

# Simple function with one default argument
def greet(name, greeting="Hello"):
    print(greeting + ", " + name)

greet("Alice", "Hi")
greet("Bob")

# Function with multiple default arguments
def create_user(username, role="user", active=True):
    print(username + ", " + role + ", " + str(active))

create_user("admin", "administrator", False)
create_user("john", "moderator")
create_user("jane")
]])

-- You can also evaluate expressions and read back results
local result = python:eval("add(10, 32)")
print("add(10,32) ->", result)
