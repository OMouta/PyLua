local PyLua = require("../../src/PyLua")
local python = PyLua.new()

python:execute([[ 
x = 7
if x < 5:
    print("small")
elif x < 10:
    print("medium")
else:
    print("large")

# chained comparisons combine checks without repeating the middle operand
value = 8
if 5 < value < 10:
    print("value is between 5 and 10")

print("strictly increasing chain:", 1 < 2 < 3)

# failing a link short-circuits further comparisons
if not (0 < value < 5):
    print("value is not less than 5")

# while + break/continue
i = 0
while i < 5:
    i = i + 1
    if i == 2:
        continue
    if i == 4:
        break
    print("i:", i)

# for over range and list
for n in range(3):
    print("range:", n)

for v in ["a", "b", "c"]:
    print("list:", v)
]])
