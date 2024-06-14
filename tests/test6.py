# Check function definition for partition in QuickSort algorithm
def partition(array: list[int], low: int, high: int) -> int:
    # Set the pivot element as the last element of the subarray
    pivot: int = array[high]
    i: int = low - 1  # Initialize index of smaller element

    # Iterate through the subarray
    j: int
    for j in range(low, high):
        # If the current element is smaller than or equal to the pivot
        if array[j] <= pivot:
            i += 1
            # Swap array[i] and array[j]
            tmp: int = array[i]
            array[i] = array[j]
            array[j] = tmp

    # Swap the pivot element with the greater element at i+1
    temp: int = array[i + 1]
    array[i + 1] = array[high]
    array[high] = temp

    # Return the partition index
    return i + 1

# Check function definition for QuickSort algorithm
def quickSort(array: list[int], low: int, high: int) -> None:
    if low < high:
        # Get the partition index
        pi: int = partition(array, low, high)

        # Sort the elements before and after the partition index
        quickSort(array, low, pi - 1)
        quickSort(array, pi + 1, high)

# Check function definition for main function
def main():
    # Create a sample list
    data: list[int] = [1, 7, 4, 1, 10, 9, -2]

    # Print the unsorted array
    print("Unsorted Array")
    size: int = len(data)
    i: int
    for i in range(size):
        print(data[i])

    # Call the QuickSort function to sort the array
    quickSort(data, 0, size - 1)

    # Print the sorted array
    print('Sorted Array in Ascending Order:')
    for i in range(size):
        print(data[i])

# Check if __main__ condition
if __name__ == "__main__":
    main()
