# Check function definition for bitwise operations
def bitwise_operations(a: int, b: int) -> list[int]:
    # Bitwise AND
    result_and: int = a & b

    # Bitwise OR
    result_or: int = a | b

    # Bitwise XOR
    result_xor: int = a ^ b

    # Bitwise NOT (complement)
    result_not_a: int = ~a
    result_not_b: int = ~b

    # Bitwise Left Shift
    result_left_shift_a: int = a << 1
    result_left_shift_b: int = b << 1

    # Bitwise Right Shift
    result_right_shift_a: int = a >> 1
    result_right_shift_b: int = b >> 1

    # Create a list with the results
    L: list[int] = [
        result_and, result_or, result_xor, result_not_a, result_not_b,
        result_left_shift_a, result_left_shift_b, result_right_shift_a, result_right_shift_b
    ]
    return L

# Check function definition for relational operations
def relational_operations(a: int, b: int) -> list[bool]:
    # Relational operations
    result_equal: bool = a == b
    result_not_equal: bool = a != b
    result_greater_than: bool = a > b
    result_less_than: bool = a < b
    result_greater_than_or_equal: bool = a >= b
    result_less_than_or_equal: bool = a <= b

    # Create a list with the results
    L: list[bool] = [
        result_equal, result_not_equal, result_greater_than, result_less_than,
        result_greater_than_or_equal, result_less_than_or_equal
    ]
    return L

# Check function definition for arithmetic operations
def arithmetic_operations(a: int, b: int) -> list[int]:
    # Arithmetic operations
    result_addition: int = a + b
    result_subtraction: int = a - b
    result_multiplication: int = a * b
    result_division: int = a / b
    result_modulus: int = a % b
    result_exponentiation: int = a ** b
    result_floor_division: int = a // b

    # Create a list with the results
    L: list[int] = [
        result_addition, result_subtraction, result_multiplication,
        result_division, result_modulus, result_exponentiation, result_floor_division
    ]
    return L

# Check function definition for logical operations
def logical_operations(a: bool, b: bool) -> list[bool]:
    # Logical AND
    result_and: bool = a and b

    # Logical OR
    result_or: bool = a or b

    # Logical NOT
    result_not_a: bool = not a
    result_not_b: bool = not b

    # Create a list with the results
    L: list[bool] = [result_and, result_or, result_not_a, result_not_b]
    return L

# Check function definition for main function
def main():
    num1: int = 10
    num2: int = 5

    # Call bitwise_operations function and print the results
    results_bitwise: list[int] = bitwise_operations(num1, num2)
    i: int = 0
    for i in range(len(results_bitwise)):
        print(results_bitwise[i])

    # Call relational_operations function and print the results
    results_relational: list[bool] = relational_operations(num1, num2)
    for i in range(len(results_relational)):
        print(results_relational[i])

    # Call arithmetic_operations function and print the results
    results_arithmetic: list[int] = arithmetic_operations(num1, num2)
    for i in range(len(results_arithmetic)):
        print(results_arithmetic[i])

    # Call logical_operations function and print the results
    results_logical: list[bool] = logical_operations(True, False)
    for i in range(len(results_logical)):
        print(results_logical[i])

# Check if __main__ condition
if __name__ == "__main__":
    main()
