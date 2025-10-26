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

# Lambda function
square = lambda x: x * x
print("square(5) =", square(5))

# lambda with default argument
increment = lambda x, inc=1: x + inc
print("increment(10) =", increment(10))
print("increment(10, 5) =", increment(10, 5))

# Function calling another function
def helper(x):
    return x + 1

def main(x):
    return helper(x) * 2
    
print("main(5) =", main(5))
]])

-- You can also evaluate expressions and read back results
local result = python:eval("add(10, 32)")
print("add(10,32) ->", result)
