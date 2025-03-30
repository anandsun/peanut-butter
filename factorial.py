def get_numbers_up_to(n: int) -> list[int]:
    """
    Generate an array of integers from 1 to n inclusive.
    
    Args:
        n (int): A positive integer
        
    Returns:
        list[int]: Array of integers from 1 to n
        
    Raises:
        ValueError: If n is not positive
    """
    if not isinstance(n, int):
        raise TypeError("Input must be an integer")
    if n < 1:
        raise ValueError("Input must be a positive integer")
    
    return list(range(1, n + 1))

def factorial(n: int) -> int:
    """
    Compute factorial of n using an iterative approach.
    
    Args:
        n (int): A non-negative integer
        
    Returns:
        int: The factorial of n
        
    Raises:
        ValueError: If n is negative
    """
    if not isinstance(n, int):
        raise TypeError("Input must be an integer")
    if n < 0:
        raise ValueError("Factorial is not defined for negative numbers")
    if n == 0 or n == 1:
        return 1
    
    numbers = get_numbers_up_to(n)
    result = 1
    for num in numbers:
        result *= num
    return result

if __name__ == "__main__":
    # Example usage
    test_numbers = [0, 5, 100, 150]
    for num in test_numbers:
        if num > 0:
            numbers = get_numbers_up_to(num)
            print(f"Numbers up to {num}: {numbers}")
        print(f"Factorial of {num}: {factorial(num)}")
        print("-" * 40) 