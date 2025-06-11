local python = require('../src/PyLua/python')

python.execute([[
# PyLua 0.2 Comprehensive Feature Showcase
print("Welcome to PyLua 0.2 - Python in Roblox!")
print()

# ===== BASIC VARIABLES AND TYPES =====
print("🔢 Variables and Types:")
name = "PyLua"
version = 0.2
is_awesome = True
nothing = None

print("Project:", name)
print("Version:", version)
print("Is awesome:", is_awesome)
print("Nothing value:", nothing)
print()

# ===== ARITHMETIC AND COMPARISONS =====
print("🧮 Math and Comparisons:")
x = 15
y = 25
sum_result = x + y
difference = y - x
product = x * y
quotient = y / x

print("x =", x, "y =", y)
print("Sum:", sum_result)
print("Difference:", difference)
print("Product:", product)
print("Quotient:", quotient)
print("x < y:", x < y)
print("x == 15:", x == 15)
print()

# ===== PYTHON DATA STRUCTURES =====
print("📦 Python Data Structures:")

# Lists
numbers = [1, 2, 3, 4, 5]
mixed_list = ["hello", 42, True, None]
print("Numbers list:", numbers)
print("Mixed list:", mixed_list)
print("First number:", numbers[0])
print("List length:", len(numbers))

# Dictionaries  
person = {"name": "Alice", "age": 30, "city": "New York"}
print("Person dict:", person)
print("Person's name:", person["name"])

# Tuples
coordinates = (10, 20, 30)
print("Coordinates tuple:", coordinates)
print("X coordinate:", coordinates[0])

# Sets
unique_numbers = {1, 2, 3, 3, 4, 4, 5}
print("Unique numbers set:", unique_numbers)
print()

# ===== CONTROL FLOW: IF/ELIF/ELSE =====
print("🔀 Control Flow - Conditionals:")
score = 85

if score >= 90:
    print("Grade: A - Excellent!")
elif score >= 80:
    print("Grade: B - Good job!")
    if score >= 85:
        print("  You're close to an A!")
elif score >= 70:
    print("Grade: C - Keep trying!")
else:
    print("Grade: F - Study more!")

print("Final score:", score)
print()

# ===== CONTROL FLOW: FOR LOOPS =====
print("🔄 Control Flow - For Loops:")
print("Counting to 5:")
for i in range(6):
    if i == 0:
        print("  Starting count...")
    elif i == 3:
        print("  Halfway there! i =", i)
    elif i == 5:
        print("  Final count! i =", i)
    else:
        print("  Count:", i)

print("Loop through a list:")
fruits = ["apple", "banana", "cherry"]
for fruit in fruits:
    print("  I like", fruit)
print()

# ===== CONTROL FLOW: WHILE LOOPS =====
print("🔁 Control Flow - While Loops:")
print("Countdown sequence:")
countdown = 5
while countdown > 0:
    if countdown == 1:
        print("  🚀 Blast off!")
    else:
        print("  Countdown:", countdown)
    countdown = countdown - 1
print("  Mission launched!")
print()

# ===== NESTED CONTROL STRUCTURES =====
print("🎯 Advanced Nesting Demo:")
print("Matrix processing simulation:")

for row in range(3):
    print("Processing row", row + 1, ":")
    
    if row == 0:
        print("  First row - initializing...")
        for col in range(2):
            print("    Column", col + 1, "= initial value")
    elif row == 1:
        print("  Middle row - processing data...")
        counter = 0
        while counter < 2:
            if counter == 0:
                print("    Processing first element")
            else:
                print("    Processing second element")
            counter = counter + 1
    else:
        print("  Final row - cleanup...")
        for col in range(2):
            if col == 0:
                print("    Saving results...")
            else:
                print("    Finalizing...")

print("Matrix processing complete!")
print()

# ===== BUILT-IN FUNCTIONS SHOWCASE =====
print("🛠️ Built-in Functions:")
test_string = "42"
test_float = 3.14159

print("Original string:", test_string)
print("String to int:", int(test_string))
print("String to float:", float(test_string))
print("Float to string:", str(test_float))
print("Float to int:", int(test_float))

print("Type checking:")
print("  type(42):", type(42))
print("  type(3.14):", type(3.14))
print("  type('hello'):", type("hello"))
print("  type(True):", type(True))
print("  type([1,2,3]):", type([1, 2, 3]))

print("Boolean conversion:")
print("  bool(1):", bool(1))
print("  bool(0):", bool(0))
print("  bool(''):", bool(""))
print("  bool('hello'):", bool("hello"))
print()

# ===== COMPLEX REAL-WORLD EXAMPLE =====
print("🌟 Real-World Example - Data Analysis:")
print("Analyzing student grades...")

students = [
    {"name": "Alice", "scores": [85, 92, 78, 96]},
    {"name": "Bob", "scores": [76, 89, 94, 82]},
    {"name": "Charlie", "scores": [95, 88, 91, 97]}
]

for student in students:
    name = student["name"]
    scores = student["scores"]
    
    print("Student:", name)
    print("  Scores:", scores)
    
    # Calculate average
    total = 0
    count = 0
    for score in scores:
        total = total + score
        count = count + 1
    
    average = total / count
    print("  Average:", average)
    
    # Determine grade
    if average >= 90:
        grade = "A"
        status = "Excellent"
    elif average >= 80:
        grade = "B"  
        status = "Good"
    elif average >= 70:
        grade = "C"
        status = "Satisfactory"
    else:
        grade = "F"
        status = "Needs Improvement"
    
    print("  Grade:", grade, "-", status)
    
    # Check for improvement
    first_half = scores[0] + scores[1]
    second_half = scores[2] + scores[3]
    
    if second_half > first_half:
        print("  📈 Trending upward!")
    elif second_half < first_half:
        print("  📉 Needs focus")
    else:
        print("  📊 Consistent performance")
    
    print()

print("🎉 PyLua 0.2 Demo Complete!")
]])