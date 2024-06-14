# Check function definition for bubble sort algorithm
def bubbleSort(array: list[int]) -> None:
    # Check for loop for iteration through the array
    i: int = 0
    for i in range(len(array)):
        swapped: bool = False
        j: int = 0
        ap: int = len(array) - i - 1

        # Check nested for loop for swapping adjacent elements
        for j in range(0, ap):
            if array[j] > array[j + 1]:
                temp: int = array[j]
                array[j] = array[j + 1]
                array[j + 1] = temp
                swapped = True

        # Check break condition for optimized bubble sort
        if not swapped:
            break

# Check function definition for main function
def main():
    # Check list creation
    data: list[int] = [1, 5, 3, 2, 5, 8]

    # Check function call for bubble sort
    bubbleSort(data)
    print('Sorted Array in Ascending Order:')

    # Check for loop for printing sorted array
    i: int = 0
    for i in range(len(data)):
        print(data[i])

# Check if __main__ condition
if __name__ == "__main__":
    main()
