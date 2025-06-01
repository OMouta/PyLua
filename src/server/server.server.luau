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
print("Float:", type(float_num), "Int:", type(int_num), "Bool:", type(bool_val))
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

-- Simple while loop test
Python.execute([[
count = 0
while count < 5:
    print("Count is:", count)
    count = count + 1
]])

-- While loop with more complex condition
Python.execute([[
x = 10
while x > 0:
    print("x =", x)
    x = x - 2
print("x is now:", x)
]])

-- Nested while loops
Python.execute([[
i = 1
while i <= 3:
    print("Outer loop i =", i)
    j = 1
    while j <= 2:
        print("  Inner loop j =", j)
        j = j + 1
    i = i + 1
]])

-- Simple for loop with range
Python.execute([[
for i in range(5):
    print("i =", i)
]])

-- For loop with range(start, stop)
Python.execute([[
for num in range(2, 7):
    print("num =", num)
]])

-- For loop with range(start, stop, step)
Python.execute([[
for even in range(0, 10, 2):
    print("even =", even)
]])

-- Nested for loops
Python.execute([[
for i in range(1, 4):
    print("Outer i =", i)
    for j in range(1, 3):
        print("  Inner j =", j)
]])

-- List literals and operations
Python.execute('my_list = [1, 2, 3, 4, 5]')
Python.execute('print("List:", my_list)')
Python.execute('print("List length:", len(my_list))')

-- List iteration
Python.execute([[
for item in [10, 20, 30]:
    print("List item:", item)
]])

-- String iteration
Python.execute([[
for char in "hello":
    print("Character:", char)
]])

-- Mixed Lists
Python.execute([[
mixed = ["apple", 42, "banana", 100]
for item in mixed:
    print("Mixed item:", item, "Type:", type(item))
]])

-- Enumerate function
Python.execute([[
fruits = ["apple", "banana", "cherry"]
for i, fruit in enumerate(fruits):
    print("Index:", i, "Fruit:", fruit)
]])

-- Enumerate with string
Python.execute([[
for i, char in enumerate("hello"):
    print("Index:", i, "Character:", char)
]])

-- Enumerate with custom start
Python.execute([[
colors = ["red", "green", "blue"]
for i, color in enumerate(colors, 1):
    print("Position:", i, "Color:", color)
]])

-- Nested loops with lists
Python.execute([=[
matrix = [[1, 2], [3, 4]]
for row in matrix:
    for item in row:
        print("Matrix item:", item)
]=])