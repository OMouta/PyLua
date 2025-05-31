local Python = require('./PyLua/python')

print("=== PyLua Python Interpreter Test ===")

-- Basic variables and built-ins
Python.execute([[
message = "Python in Luau!"
length = len(message)
print("Message:", message)
print("Length:", length)
]])

-- Math operations and new built-ins
Python.execute([[
numbers = range(1, 11)
print("Numbers 1-10:", numbers)

total = sum(numbers)
print("Sum of 1-10:", total)

minimum = min(numbers)
maximum = max(numbers)
print("Min:", minimum, "Max:", maximum)
]])

-- Conditional with grades
Python.execute([[
score = 85

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
]])

-- More built-in functions
Python.execute([[
pi_approx = 3.14159
rounded_pi = round(pi_approx, 2)
print("Pi rounded to 2 places:", rounded_pi)

negative = -42
absolute = abs(negative)
print("Absolute value of", negative, "is", absolute)
]])

-- Type conversions
Python.execute([[
float_num = float("3.14")
int_num = int(float_num)
bool_val = bool(1)
print("Float:", float_num, "Int:", int_num, "Bool:", bool_val)
]])

-- Power function
Python.execute([[
base = 2
exponent = 8
result = pow(base, exponent)
print(base, "to the power of", exponent, "is", result)
]])

-- String comparison
Python.execute([[
name = "PyLua"

if name == "Python":
    print("This is Python")
elif name == "Lua":
    print("This is Lua")
elif name == "PyLua":
    print("This is PyLua - Python in Luau!")
else:
    print("Unknown language")
]])

-- Nested conditionals
Python.execute([[
x = 10
if x > 0:
    print("x is positive")
    if x % 2 == 0:
        print("x is even")
    else:
        print("x is odd")
else:
    print("x is not positive")
]])
