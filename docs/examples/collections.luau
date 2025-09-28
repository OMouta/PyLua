local PyLua = require("../../src/PyLua")
local python = PyLua.new()

python:execute([[ 
# Lists, tuples, dicts, sets
nums = [1, 2, 3]
pair = ("a", 42)
conf = {"host": "localhost", "port": 8080}
letters = {"a", "b", "c"}

print("nums:", nums)
print("pair:", pair)
print("conf:", conf)
print("letters:", letters)

# Looping
for n in nums:
    print("num:", n)

# Builtins interop
print("len(nums) =", len(nums))
print("min(nums) =", min(nums))
print("max(nums) =", max(nums))
print("sum(nums) =", sum(nums))

# Methods
nums.append(4)
print("after append:", nums)
print("popped:", nums.pop())
print("after pop:", nums)
print("contains 2?", 2 in nums)

# List comprehensions
squares = [x * x for x in nums]
print("squares:", squares)
]])
