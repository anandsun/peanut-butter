const std = @import("std");
const fix = @import("sorted_runs_sequence.zig");

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
            // Find the first occurrence
            var first = mid;
            while (first > 0 and arr[first - 1] == value) {
                first -= 1;
            }
            return first;
        } else if (arr[mid] < value) {
            left = mid + 1;
        } else {
            right = mid;
        }
    }
    
    return null;
}

/// Processes even numbers in the array according to the specified rules
pub fn redistributeTwoFactors(N: u64) ![]u64 {
    var seq = try fix.SortedRunsSequence(u64).init(std.heap.page_allocator, N);
    defer seq.deinit();

    const lower_bound = 3 * N / 8;
    
    var current_array = seq.sortedArray();
    defer std.heap.page_allocator.free(current_array);

    // Process all even numbers between 3N/8 and N
    var i: usize = lower_bound;
    while (i < N) : (i += 1) {
        const current_value = seq.valueAt(i);
        if (current_value % 2 == 0) {
            // Replace even number with its half
            const divided_value = current_value / 2;
            _ = seq.modify(i, current_value, divided_value);
            
            // Double the smallest element in the sequence
            const smallest_idx = seq.minimumIndex();
            const smallest_val = seq.valueAt(smallest_idx);
            _ = seq.modify(smallest_idx, smallest_val, smallest_val * 2);
            
            current_array = seq.sortedArray();

            // If the divided value is still even and above lower_bound, process it again
            if (divided_value % 2 == 0 and divided_value > lower_bound) {
                
                // Replace even number with its half again
                const new_divided_value = divided_value / 2;
                _ = seq.modify(i, divided_value, new_divided_value);
                
                // Double the smallest element again
                const new_smallest_idx = seq.minimumIndex();
                const new_smallest_val = seq.valueAt(new_smallest_idx);
                _ = seq.modify(new_smallest_idx, new_smallest_val, new_smallest_val * 2);
                
                current_array = seq.sortedArray();
            }
        }
    }

    return seq.sortedArray();
}

test "redistribute two factors - N=15" {
    std.debug.print("\n=== Starting test for N=15 ===\n", .{});
    const result = try redistributeTwoFactors(15);
    defer std.heap.page_allocator.free(result);

    const expected = [_]u64{ 4, 4, 4, 4, 5, 5, 6, 6, 6, 7, 7, 9, 11, 13, 15 };
    try std.testing.expectEqualSlices(u64, &expected, result);
}

test "redistribute two factors - N=33" {
    const result = try redistributeTwoFactors(33);
    defer std.heap.page_allocator.free(result);

    const expected = [_]u64{ 7, 8, 8, 8, 8, 8, 8, 9, 9, 10, 10, 10, 11, 11, 12, 12, 12, 12, 13, 13, 14, 14, 15, 15, 17, 19, 21, 23, 25, 27, 29, 31, 33 };
    try std.testing.expectEqualSlices(u64, &expected, result);
} 

test "redistribute two factors - N=65" {
    const result = try redistributeTwoFactors(65);
    defer std.heap.page_allocator.free(result);

    const expected = [_]u64{ 13, 14, 14, 14, 14, 15, 15, 15, 16, 16, 16, 16, 16, 16, 16, 17, 17, 18, 18, 18, 19, 19, 20, 20, 20, 20, 21, 21, 22, 22, 22, 23, 23, 24, 24, 24, 24, 24, 25, 25, 26, 26, 27, 27, 29, 29, 31, 31, 33, 35, 37, 39, 41, 43, 45, 47, 49, 51, 53, 55, 57, 59, 61, 63, 65 };
    try std.testing.expectEqualSlices(u64, &expected, result);
} 
