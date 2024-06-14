# Check class definition for Shape
class Shape:
    def __init__(self, id: str):
        self.id: str = id

    # Check method definition for printing the id
    def print_id(self) -> None:
        print("id")
        print(self.id)

# Check class definition for Polygon, inherited from Shape
class Polygon(Shape):
    def __init__(self, id: str, sides: int):
        self.id = id
        self.sides: int = sides

    # Check method definition for printing the number of sides
    def print_sides(self) -> None:
        print("Sides:")
        print(self.sides)

# Check class definition for Triangle, inherited from Polygon
class Triangle(Polygon):
    def __init__(self, id: str, side1: int, side2: int, side3: int):
        self.id = id
        self.sides = 3
        self.side1: int = side1
        self.side2: int = side2
        self.side3: int = side3

    # Check method definition for calculating the perimeter
    def perimeter(self) -> int:
        return self.side1 + self.side2 + self.side3

    # Check method definition for displaying the information
    def display_info(self):
        self.print_id()
        self.print_sides()
        print("Perimeter:")
        print(self.perimeter())

# Check class definition for Rectangle, inherited from Polygon
class Rectangle(Polygon):
    def __init__(self, id: str, width: int, height: int):
        self.id = id
        self.sides = 4
        self.width: int = width
        self.height: int = height

    # Check method definition for calculating the area
    def area(self) -> int:
        return self.width * self.height

    # Check method definition for calculating the perimeter
    def perimeter(self) -> int:
        return 2 * (self.width + self.height)

    # Check method definition for displaying the information
    def display_info(self):
        self.print_id()
        self.print_sides()
        print("Perimeter:")
        print(self.perimeter())
        print("Area:")
        print(self.area())

# Check function definition for main function
def main():
    # Check object creation for Triangle
    triangle: Triangle = Triangle("t1", 3, 4, 5)
    triangle.display_info()
    print("")

    # Check object creation for Rectangle
    rectangle: Rectangle = Rectangle("r1", 6, 8)
    rectangle.display_info()

# Check if __main__ condition
if __name__ == "__main__":
    main()
