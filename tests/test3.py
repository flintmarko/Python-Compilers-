# Check function definition for finding the nth Fibonacci number
def fib(a: int) -> int:
    if a == 0:
        return 0
    elif a == 1:
        return 1
    else:
        # Check recursive function call
        return fib(a - 1) + fib(a - 2)

# Check function definition for finding the maximum element in a list
def find_max(arr: list[int]) -> int:
    max: int = arr[0]
    i: int = 0
    # Check for loop for iterating through the list
    for i in range(1, len(arr)):
        if arr[i] > max:
            max = arr[i]
    return max

# Check function definition for finding the minimum element in a list
def find_min(arr: list[int]) -> int:
    min: int = arr[0]
    i: int = 0
    # Check for loop for iterating through the list
    for i in range(1, len(arr)):
        if arr[i] < min:
            min = arr[i]
    return min

# Check function definition for main function
def main():
    # Check list creation
    arr: list[int] = [1, 8, 9, 4, 10, 3, 6, 4]
    n: int = len(arr)

    # Check printing length of the list
    print("Length of list is")
    print(len(arr))

    # Check function calls for finding maximum and minimum elements
    print("Maximum number in the array:")
    max_element: int = find_max(arr)
    print(max_element)

    print("Minimum number in the array:")
    min_element: int = find_min(arr)
    print(min_element)

    # Check printing Fibonacci series within the range of minimum and maximum elements
    print("Fibonacci series in range min_element and max_element:")
    i: int = 0
    for i in range(min_element, max_element):
        print(fib(i))

# Check if __main__ condition
if __name__ == '__main__':
    main()
