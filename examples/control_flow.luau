local PyLua = require("../src/PyLua")
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

# Iterate over list of tuples
for x, y in [(1, 2), (3, 4), (5, 6)]:
    print(f"x={x}, y={y}, sum={x + y}")

# Parenthesized tuple targets work too
for (a, b) in [(10, 20), (30, 40)]:
    print(f"a={a}, b={b}, product={a * b}")

# Triple tuple destructuring
coordinates = [(1, 2, 3), (4, 5, 6), (7, 8, 9)]
for x, y, z in coordinates:
    print(f"point: ({x}, {y}, {z})")

# Nested tuple destructuring
data = [((1, 2), 100), ((3, 4), 200)]
for (a, b), value in data:
    print(f"pair ({a}, {b}) has value {value}")
]])
