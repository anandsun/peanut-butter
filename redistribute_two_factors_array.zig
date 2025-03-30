const std = @import("std");
const testing = std.testing;
const fix = @import("fix_mostly_sorted_array.zig");

/// Returns true if n is a power of 2
fn isPowerOfTwo(n: u64) bool {
    return n > 0 and (n & (n - 1)) == 0;
}

/// Returns true if n is a power of 4
fn isPowerOfFour(n: u64) bool {
    return isPowerOfTwo(n) and (n & 0xAAAAAAAAAAAAAAAA) == 0;
}

/// Finds the index of a value in a sorted array using binary search
fn findIndex(comptime T: type, arr: []const T, value: T) ?usize {
    var left: usize = 0;
    var right: usize = arr.len;
    
    while (left < right) {
        const mid = left + (right - left) / 2;
        if (arr[mid] == value) {
            return mid;
        } else if (arr[mid] < value) {
            left = mid + 1;
        } else {
            right = mid;
        }
    }
    
    return null;
}

/// Processes even numbers in the array according to the specified rules
pub fn redistributeTwoFactors(n: u64) ![]u64 {
    // Create array of integers from 1 to N
    var arr = try std.heap.page_allocator.alloc(u64, n);
    for (0..n) |i| {
        arr[i] = @intCast(i + 1);
    }

    const three_eighths = n * 3 / 8;

    // Process even numbers > 3/8 N
    var i: usize = three_eighths;
    while (i < n) : (i += 1) {
        if (arr[i] % 2 == 0) {
            const old_val = arr[i];
            const divided_val = old_val / 2;
            arr[i] = divided_val;
            arr[0] *= 2;
            
            // Fix the sorting between the first element and the divided value
            const fixed = try fix.fixMostlySorted(u64, arr, 0, i);
            if (!fixed) {
                std.heap.page_allocator.free(arr);
                return error.FailedToFixSorting;
            }

            // If the divided value is still even and > three_eighths, we need to process it again
            if (divided_val % 2 == 0 and divided_val > three_eighths) {
                // Find where the divided value ended up
                const new_index = findIndex(u64, arr, divided_val).?;
                const new_val = arr[new_index];
                arr[new_index] = new_val / 2;
                arr[0] *= 2;
                
                // Fix the sorting between the first element and the new divided value
                const fixed_again = try fix.fixMostlySorted(u64, arr, 0, new_index);
                if (!fixed_again) {
                    std.heap.page_allocator.free(arr);
                    return error.FailedToFixSorting;
                }
            }
        }
    }

    std.debug.print("Final array: {any}\n", .{arr});
    return arr;
}

test "redistribute two factors - N=15" {
    const result = try redistributeTwoFactors(15);
    defer std.heap.page_allocator.free(result);

    const expected = [_]u64{ 4, 4, 4, 4, 5, 5, 6, 6, 6, 7, 7, 9, 11, 13, 15 };
    try testing.expectEqualSlices(u64, &expected, result);
}

test "redistribute two factors - N=33" {
    const result = try redistributeTwoFactors(33);
    defer std.heap.page_allocator.free(result);

    const expected = [_]u64{ 7, 8, 8, 8, 8, 8, 8, 9, 9, 10, 10, 10, 11, 11, 12, 12, 12, 12, 13, 13, 14, 14, 15, 15, 17, 19, 21, 23, 25, 27, 29, 31, 33 };
    try testing.expectEqualSlices(u64, &expected, result);
} 

test "redistribute two factors - N=65" {
    const result = try redistributeTwoFactors(65);
    defer std.heap.page_allocator.free(result);

    const expected = [_]u64{ 13, 14, 14, 14, 14, 15, 15, 15, 16, 16, 16, 16, 16, 16, 16, 17, 17, 18, 18, 18, 19, 19, 20, 20, 20, 20, 21, 21, 22, 22, 22, 23, 23, 24, 24, 24, 24, 24, 25, 25, 26, 26, 27, 27, 29, 29, 31, 31, 33, 35, 37, 39, 41, 43, 45, 47, 49, 51, 53, 55, 57, 59, 61, 63, 65 };
    try testing.expectEqualSlices(u64, &expected, result);
} 