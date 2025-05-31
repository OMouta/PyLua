local Python = require('./PyLua/python')

print("=== PyLua Python Interpreter Test ===")

Python.execute([[
message = "Python in Luau!"
length = len(message)

score = 60

if score >= 90:
    print("Grade: A")
elif score >= 80:
    print("Grade: B")
elif score >= 70:
    print("Grade: C")
elif score >= 60:
    print("Grade: D")
else:
    print("Grade: F")

print("Score:", score)

name = "PyLua"

if name == "Python":
    print("This is Python")
elif name == "Lua":
    print("This is Lua")
elif name == "PyLua":
    print("This is PyLua - Python in Luau!")
else:
    print("Unknown language")

print("Message:", message)
print("Length:", length)
]])