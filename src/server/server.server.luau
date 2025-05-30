local Python = require('./PyLua/python')

print("=== PyLua Python Interpreter Test ===")

Python.execute([[
# Test variables and basic operations
message = "PyLua - Python in Luau!"
length = len(message)
print("Message:", message)
print("Length:", length)

# Test conditional statements with elif
score = 85

if score >= 90:
    print("Grade: A")
elif score >= 80:
    print("Grade: B")
elif score >= 70:
    print("Grade: C")
else:
    print("Grade: F")

print("Final score:", score)
]])