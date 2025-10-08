local PyLua = require("../src/PyLua")
local python = PyLua.new()

python:execute([[ 
def divide(a, b):
    return a / b

try:
    print("divide(10, 2) =", divide(10, 2))
    print("divide(5, 0) =", divide(5, 0))
except ZeroDivisionError as e:
    print("Error:", e)

try:
    array = [1, 2, 3]
    print("Accessing array[5]:", array[5])
except IndexError as e:
    print("Error:", e)

try:
    print("Undefined variable x:", x)
except NameError as e:
    print("Error:", e)

try:
    value = int("not_a_number")
except:
    print("Error: Could not convert string to int")

# Unhandled exception example
print("This will raise an unhandled exception:")
print(1 / 0)
]])
