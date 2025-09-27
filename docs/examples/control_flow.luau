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
