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

/// Prints the current state of slices for debugging
fn printSliceState(seq: *fix.SortedSequence(u64), msg: []const u8) void {
    std.debug.print("\n=== {s} ===\n", .{msg});
    for (seq.slices.items, 0..) |slice, i| {
        std.debug.print("Slice {d}: [{d}..{d}] = ", .{i, slice.start, slice.end});
        var j = slice.start;
        while (j <= slice.end) : (j += 1) {
            std.debug.print("{d} ", .{seq.valueAt(j)});
        }
        std.debug.print("\n", .{});
    }
    std.debug.print("==========\n", .{});
}

/// Processes even numbers in the array according to the specified rules
pub fn redistributeTwoFactors(seq: *fix.SortedSequence(u64)) !void {
    const N = seq.array.len;
    const lower_bound = 3 * N / 8;
    std.debug.print("\nStarting redistribution with N={d}, lower_bound={d}\n", .{N, lower_bound});
    
    var current_array = seq.sortedArray();
    defer std.heap.page_allocator.free(current_array);
    printArrayState(current_array, "Initial array state");
    printSliceState(seq, "Initial slice state");

    // Process all even numbers between 3N/8 and N
    var i: usize = lower_bound;
    while (i < N) : (i += 1) {
        const current_value = seq.valueAt(i);
        if (current_value % 2 == 0) {
            std.debug.print("\nProcessing even number at index {d}: {d}\n", .{i, current_value});
            
            // Replace even number with its half
            const divided_value = current_value / 2;
            _ = seq.modify(i, current_value, divided_value);
            std.debug.print("Divided {d} by 2 to get {d} at index {d}\n", .{current_value, divided_value, i});
            printSliceState(seq, "After dividing value");
            
            // Double the smallest element in the sequence
            const smallest_idx = seq.minimumIndex();
            const smallest_val = seq.valueAt(smallest_idx);
            std.debug.print("Found smallest element at index {d}: {d}\n", .{smallest_idx, smallest_val});
            _ = seq.modify(smallest_idx, smallest_val, smallest_val * 2);
            std.debug.print("Multiplied smallest element {d} by 2 to get {d}\n", .{smallest_val, smallest_val * 2});
            printSliceState(seq, "After doubling smallest");
            
            current_array = seq.sortedArray();
            printArrayState(current_array, "After modifications");

            // If the divided value is still even and above lower_bound, process it again
            if (divided_value % 2 == 0 and divided_value > lower_bound) {
                std.debug.print("\nReprocessing value {d} at index {d}\n", .{divided_value, i});
                
                // Replace even number with its half again
                const new_divided_value = divided_value / 2;
                _ = seq.modify(i, divided_value, new_divided_value);
                std.debug.print("Divided {d} by 2 again to get {d} at index {d}\n", .{divided_value, new_divided_value, i});
                printSliceState(seq, "After dividing value again");
                
                // Double the smallest element again
                const new_smallest_idx = seq.minimumIndex();
                const new_smallest_val = seq.valueAt(new_smallest_idx);
                std.debug.print("Found smallest element at index {d}: {d}\n", .{new_smallest_idx, new_smallest_val});
                _ = seq.modify(new_smallest_idx, new_smallest_val, new_smallest_val * 2);
                std.debug.print("Multiplied smallest element {d} by 2 again to get {d}\n", .{new_smallest_val, new_smallest_val * 2});
                printSliceState(seq, "After doubling smallest again");
                
                current_array = seq.sortedArray();
                printArrayState(current_array, "After reprocessing modifications");
            }
        }
    }
}

test "redistribute two factors - N=15" {
    std.debug.print("\n=== Starting test for N=15 ===\n", .{});
    var result = try fix.SortedSequence(u64).init(std.heap.page_allocator, 15);
    defer result.deinit();

    try redistributeTwoFactors(&result);

    const expected = [_]u64{ 4, 4, 4, 4, 5, 5, 6, 6, 6, 7, 7, 9, 11, 13, 15 };
    try testing.expectEqualSlices(u64, &expected, result.sortedArray());
}
