# Check recursive function definition
def fact(n: int) -> int:
    if not n:
        return 1
    if n < 3:
        return n
    return n * fact(n - 1)

# Check function definition with control flow statements
def main():
    # Check variable declaration and initialization
    i: int = 0

    # Check for loop with continue and break statements
    for i in range(10):
        if i == 3:
            continue
        print(i)
        if i == 4:
            break
    print(i)

    # Check while loop with continue statement
    i += 1
    while i < 10:
        print(i + 1)
        if i == 7:
            print(i)
        i += 2
        if i:
            continue
        i += 1

    # Check boolean expression evaluation
    if False ^ True:
        print(123)

    # Check list creation and indexing
    i = 8
    a: list[int] = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
    x: int = a[0] - 1
    print(x)
    print(a[i] - 1)

    # Check for loop with continue statement and list indexing
    for i in range(2, 10):
        if i == 5:
            continue
        print(i)
        print((a[i] - 1))
        print(a[i] - 1)

    # Check function call
    print(fact(6))

    # Check integer division
    num: int = 64 // 17
    print(num)

# Check if __main__ condition
if __name__ == "__main__":
    main()
