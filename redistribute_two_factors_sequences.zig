const std = @import("std");
const testing = std.testing;
const fix = @import("fix_mostly_sorted_sequences.zig");

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

/// Prints the current state of the array
fn printArrayState(arr: []const u64, msg: []const u8) void {
    std.debug.print("\n=== {s} ===\n", .{msg});
    for (0..arr.len) |i| {
        std.debug.print("[{d}]: {d}\n", .{i, arr[i]});
    }
    std.debug.print("==========\n", .{});
}

/// Processes even numbers in the array according to the specified rules
pub fn redistributeTwoFactors(n: u64) ![]u64 {
    // Create array of integers from 1 to N
    var arr = try std.heap.page_allocator.alloc(u64, n);
    for (0..n) |i| {
        arr[i] = @intCast(i + 1);
    }

    // Calculate the lower bound (3N/8)
    const lower_bound = (3 * n) / 8;
    std.debug.print("\nStarting redistribution with N={d}, lower_bound={d}\n", .{n, lower_bound});
    printArrayState(arr, "Initial array state");

    // Initialize the sorted sequence
    var seq = try fix.SortedSequence(u64).init(std.heap.page_allocator, arr);
    defer seq.deinit();
    
    // Add initial elements to sequence
    for (0..n) |i| {
        seq.add(i, arr[i]);
    }
    
    // Process even numbers between 3N/8 and N
    var i: usize = lower_bound;
    while (i < n) : (i += 1) {
        const current_value = arr[i];
        if (current_value % 2 == 0) {
            std.debug.print("\nProcessing even number at index {d}: {d}\n", .{i, current_value});
            
            // Replace even number with its half
            const divided_value = current_value / 2;
            arr[i] = divided_value;
            std.debug.print("Divided {d} by 2 to get {d} at index {d}\n", .{current_value, divided_value, i});
            
            // Double the smallest element in the sequence
            const smallest_idx = seq.first_range.?.start;
            const smallest_val = arr[smallest_idx];
            arr[smallest_idx] = smallest_val * 2;
            std.debug.print("Multiplied smallest element {d} by 2 to get {d}\n", .{smallest_val, arr[smallest_idx]});
            
            printArrayState(arr, "Before fixing sort");
            
            // Fix sorting after both operations
            if (try fix.fixMostlySorted(u64, &seq, smallest_idx, i)) |new_seq| {
                seq.deinit();
                seq = new_seq;
            }
            
            printArrayState(arr, "After fixing sort");

            // Check if we should reprocess this value
            const should_reprocess = divided_value % 2 == 0 and divided_value > lower_bound;
            std.debug.print("Should reprocess? {}\n", .{should_reprocess});
            
            if (should_reprocess) {
                std.debug.print("\nReprocessing value {d}\n", .{divided_value});
                
                // Find where the divided value ended up in the sequence
                var current = seq.first_range;
                var found_idx: ?usize = null;
                
                while (current) |range| : (current = range.next) {
                    var j = range.start;
                    while (j <= range.end) : (j += 1) {
                        if (arr[j] == divided_value) {
                            found_idx = j;
                            break;
                        }
                    }
                    if (found_idx != null) break;
                }
                
                if (found_idx) |idx| {
                    std.debug.print("Found value {d} at index {d}\n", .{divided_value, idx});
                    
                    // Replace even number with its half again
                    arr[idx] = divided_value / 2;
                    std.debug.print("Divided {d} by 2 again to get {d} at index {d}\n", .{divided_value, arr[idx], idx});
                    
                    // Double the smallest element again
                    const new_smallest_idx = seq.first_range.?.start;
                    const new_smallest_val = arr[new_smallest_idx];
                    arr[new_smallest_idx] = new_smallest_val * 2;
                    std.debug.print("Multiplied smallest element {d} by 2 again to get {d}\n", .{new_smallest_val, arr[new_smallest_idx]});
                    
                    printArrayState(arr, "Before fixing sort (reprocess)");
                    
                    // Fix sorting after both operations
                    if (try fix.fixMostlySorted(u64, &seq, new_smallest_idx, idx)) |new_seq| {
                        seq.deinit();
                        seq = new_seq;
                    }
                    
                    printArrayState(arr, "After fixing sort (reprocess)");
                }
            }
        }
    }

    // Copy the final sorted sequence back to the array
    seq.copyToArray(arr);
    printArrayState(arr, "Final array state");
    return arr;
}

test "redistribute two factors - N=15" {
    std.debug.print("\n=== Starting test for N=15 ===\n", .{});
    const result = try redistributeTwoFactors(15);
    defer std.heap.page_allocator.free(result);

    const expected = [_]u64{ 4, 4, 4, 4, 5, 5, 6, 6, 6, 7, 7, 9, 11, 13, 15 };
    try testing.expectEqualSlices(u64, &expected, result);
}

test "redistribute two factors - N=33" {
    std.debug.print("\n=== Starting test for N=33 ===\n", .{});
    const result = try redistributeTwoFactors(33);
    defer std.heap.page_allocator.free(result);

    const expected = [_]u64{ 7, 8, 8, 8, 8, 8, 8, 9, 9, 10, 10, 10, 11, 11, 12, 12, 12, 12, 13, 13, 14, 14, 15, 15, 17, 19, 21, 23, 25, 27, 29, 31, 33 };
    try testing.expectEqualSlices(u64, &expected, result);
} 

test "redistribute two factors - N=65" {
    std.debug.print("\n=== Starting test for N=65 ===\n", .{});
    const result = try redistributeTwoFactors(65);
    defer std.heap.page_allocator.free(result);

    const expected = [_]u64{ 13, 14, 14, 14, 14, 15, 15, 15, 16, 16, 16, 16, 16, 16, 16, 17, 17, 18, 18, 18, 19, 19, 20, 20, 20, 20, 21, 21, 22, 22, 22, 23, 23, 24, 24, 24, 24, 24, 25, 25, 26, 26, 27, 27, 29, 29, 31, 31, 33, 35, 37, 39, 41, 43, 45, 47, 49, 51, 53, 55, 57, 59, 61, 63, 65 };
    try testing.expectEqualSlices(u64, &expected, result);
} 