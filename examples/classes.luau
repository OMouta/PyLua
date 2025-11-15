local PyLua = require("../src/PyLua")
local python = PyLua.new()

python:execute([[ 
class Person:
    def __init__(self, name, age):
        self.name = name
        self.age = age

    def greet(self):
        return f"Hello, my name is {self.name} and I am {self.age} years old."

person = Person("Alice", 30)
print(person.greet())

class Student(Person):
    def __init__(self, name, age, student_id):
        super().__init__(name, age)
        self.student_id = student_id

    def study(self, subject):
        return f"{self.name} is studying {subject}."

student = Student("Bob", 20, "S12345")
print(student.greet())
print(student.study("Mathematics"))
]])

python:execute([[ 
class Rectangle:
    def __init__(self, width, height):
        self.width = width
        self.height = height

    def area(self):
        return self.width * self.height
    
    def perimeter(self):
        return 2 * (self.width + self.height)
    
    def scale(self, factor):
        self.width *= factor
        self.height *= factor
    
    def __str__(self):
        return f"Rectangle(width={self.width}, height={self.height})"

rect = Rectangle(4, 5)
print("Area:", rect.area())
print("Perimeter:", rect.perimeter())
rect.scale(2)
print("Scaled Rectangle:", rect)
]])