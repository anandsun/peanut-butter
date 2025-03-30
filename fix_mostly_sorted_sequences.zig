const std = @import("std");

/// Represents a slice of the array that is in sorted order
const Slice = struct {
    start: usize,
    end: usize,
};

/// Represents a sorted sequence by tracking slices of sorted indices
pub fn SortedSequence(comptime T: type) type {
    return struct {
        const Self = @This();
        
        /// Array containing the values
        array: []T,
        /// Dynamic array of sorted slices
        slices: std.ArrayList(Slice),
        /// Allocator for slices
        allocator: std.mem.Allocator,

        pub fn init(allocator: std.mem.Allocator, n: usize) !Self {
            // Create array of integers from 1 to N
            var arr = try allocator.alloc(T, n);
            for (0..n) |i| {
                arr[i] = @intCast(i + 1);
            }

            // Create initial slice covering entire array
            var slices = std.ArrayList(Slice).init(allocator);
            try slices.append(.{
                .start = 0,
                .end = n - 1,
            });

            return Self{
                .array = arr,
                .slices = slices,
                .allocator = allocator,
            };
        }

        pub fn deinit(self: *Self) void {
            self.slices.deinit();
            self.allocator.free(self.array);
        }

        /// Returns the value at the given index in the underlying array
        pub fn valueAt(self: *const Self, index: usize) T {
            return self.array[index];
        }

        /// Returns the index of the minimum value in the sequence
        pub fn minimumIndex(self: *const Self) usize {
            return self.slices.items[0].start;
        }

        /// Modifies a value at the given index if it matches the expected value
        pub fn modify(self: *Self, index: usize, expected_value: T, new_value: T) bool {
            if (self.array[index] != expected_value) {
                return false;
            }
            self.array[index] = new_value;
            
            std.debug.print("\n=== Starting modify for index {d}: {d} -> {d} ===\n", .{index, expected_value, new_value});
            std.debug.print("Current array state: ", .{});
            for (0..self.array.len) |i| {
                std.debug.print("{d} ", .{self.array[i]});
            }
            std.debug.print("\nCurrent slices:\n", .{});
            for (self.slices.items, 0..) |slice, i| {
                std.debug.print("  Slice {d}: [{d}..={d}] values: ", .{i, slice.start, slice.end});
                for (slice.start..slice.end + 1) |j| {
                    std.debug.print("{d} ", .{self.array[j]});
                }
                std.debug.print("\n", .{});
            }
            
            // Find the slice containing the modified index
            var slice_idx: usize = 0;
            while (slice_idx < self.slices.items.len) {
                const slice = self.slices.items[slice_idx];
                if (index >= slice.start and index <= slice.end) {
                    std.debug.print("Found containing slice: [{d}..={d}]\n", .{slice.start, slice.end});
                    
                    // Value is within this slice
                    var is_out_of_order = false;
                    var slice_to_split: ?usize = null;
                    var split_value: T = new_value;
                    
                    std.debug.print("Checking neighbors for value {d} at index {d}\n", .{new_value, index});
                    
                    // Check if value is out of order with respect to immediate neighbors
                    // First check left neighbor
                    if (index > slice.start) {
                        // Check against element to the left within same slice
                        std.debug.print("  Checking left neighbor within slice: {d} at index {d}\n", 
                            .{self.array[index - 1], index - 1});
                        if (self.array[index] < self.array[index - 1]) {
                            std.debug.print("  Value {d} is less than left neighbor {d}\n", 
                                .{self.array[index], self.array[index - 1]});
                            is_out_of_order = true;
                            slice_to_split = slice_idx;
                            split_value = self.array[index - 1];
                        }
                    } else if (slice_idx > 0) {
                        // Check against rightmost element of previous slice
                        const prev_slice = self.slices.items[slice_idx - 1];
                        std.debug.print("  Checking left neighbor from previous slice: {d} at index {d}\n", 
                            .{self.array[prev_slice.end], prev_slice.end});
                        if (self.array[index] < self.array[prev_slice.end]) {
                            std.debug.print("  Value {d} is less than left neighbor {d}\n", 
                                .{self.array[index], self.array[prev_slice.end]});
                            is_out_of_order = true;
                            slice_to_split = slice_idx - 1;
                            split_value = self.array[prev_slice.end];
                        }
                    }
                    
                    // Then check right neighbor
                    if (!is_out_of_order) {
                        if (index < slice.end) {
                            // Check against element to the right within same slice
                            std.debug.print("  Checking right neighbor within slice: {d} at index {d}\n", 
                                .{self.array[index + 1], index + 1});
                            if (self.array[index] > self.array[index + 1]) {
                                std.debug.print("  Value {d} is greater than right neighbor {d}\n", 
                                    .{self.array[index], self.array[index + 1]});
                                is_out_of_order = true;
                                slice_to_split = slice_idx;
                                split_value = self.array[index + 1];
                            }
                        } else if (slice_idx < self.slices.items.len - 1) {
                            // Check against leftmost element of next slice
                            const next_slice = self.slices.items[slice_idx + 1];
                            std.debug.print("  Checking right neighbor from next slice: {d} at index {d}\n", 
                                .{self.array[next_slice.start], next_slice.start});
                            if (self.array[index] > self.array[next_slice.start]) {
                                std.debug.print("  Value {d} is greater than right neighbor {d}\n", 
                                    .{self.array[index], self.array[next_slice.start]});
                                is_out_of_order = true;
                                slice_to_split = slice_idx + 1;
                                split_value = self.array[next_slice.start];
                            }
                        }
                    }
                    
                    if (is_out_of_order) {
                        std.debug.print("Value {d} at index {d} is out of order\n", .{new_value, index});
                        
                        // First split the appropriate slice
                        const split_slice = self.slices.items[slice_to_split.?];
                        const split_idx = findCorrectPosition(T, self.array, split_value, split_slice.start, split_slice.end);
                        std.debug.print("Binary search found split point at index {d} in slice [{d}..={d}]\n", 
                            .{split_idx, split_slice.start, split_slice.end});
                        
                        // Remove the original slice
                        _ = self.slices.orderedRemove(slice_to_split.?);
                        
                        // Collect all new slices we need to insert
                        var new_slices = std.ArrayList(Slice).init(self.allocator);
                        defer new_slices.deinit();
                        
                        // Add the split slices from the first split
                        if (split_idx > split_slice.start) {
                            new_slices.append(.{
                                .start = split_slice.start,
                                .end = split_idx - 1,
                            }) catch return false;
                        }
                        
                        if (split_idx <= split_slice.end) {
                            new_slices.append(.{
                                .start = split_idx,
                                .end = split_slice.end,
                            }) catch return false;
                        }
                        
                        // If the slice we just split contains our modified value's index,
                        // we need to split it again at that index
                        if (index >= split_slice.start and index <= split_slice.end) {
                            std.debug.print("Modified value's index {d} is in the split slice, splitting it again\n", .{index});
                            
                            // Find which of the new slices contains our index
                            for (new_slices.items, 0..) |new_slice, i| {
                                if (index >= new_slice.start and index <= new_slice.end) {
                                    // Remove this slice from new_slices
                                    _ = new_slices.orderedRemove(i);
                                    
                                    // Add the split slices
                                    if (index > new_slice.start) {
                                        new_slices.append(.{
                                            .start = new_slice.start,
                                            .end = index - 1,
                                        }) catch return false;
                                    }
                                    
                                    new_slices.append(.{
                                        .start = index,
                                        .end = index,
                                    }) catch return false;
                                    
                                    if (index + 1 <= new_slice.end) {
                                        new_slices.append(.{
                                            .start = index + 1,
                                            .end = new_slice.end,
                                        }) catch return false;
                                    }
                                    break;
                                }
                            }
                        }
                        
                        // Check if any of the new slices need to be split further
                        var i: usize = 0;
                        while (i < new_slices.items.len) {
                            const curr_slice = new_slices.items[i];
                            if (curr_slice.start != curr_slice.end) {  // Skip singleton slices
                                const slice_start_val = self.array[curr_slice.start];
                                const slice_end_val = self.array[curr_slice.end];
                                if (slice_start_val < new_value and slice_end_val > new_value) {
                                    // This slice needs to be split
                                    const inner_split_idx = findCorrectPosition(T, self.array, new_value, curr_slice.start, curr_slice.end);
                                    
                                    // Remove the current slice
                                    _ = new_slices.orderedRemove(i);
                                    
                                    // Add the split parts
                                    if (inner_split_idx > curr_slice.start) {
                                        new_slices.insert(i, .{
                                            .start = curr_slice.start,
                                            .end = inner_split_idx - 1,
                                        }) catch return false;
                                        i += 1;
                                    }
                                    
                                    if (inner_split_idx <= curr_slice.end) {
                                        new_slices.insert(i, .{
                                            .start = inner_split_idx,
                                            .end = curr_slice.end,
                                        }) catch return false;
                                        i += 1;
                                    }
                                } else {
                                    i += 1;
                                }
                            } else {
                                i += 1;
                            }
                        }
                        
                        // Insert all new slices in sorted order
                        for (new_slices.items) |new_slice| {
                            std.debug.print("Inserting slice: [{d}..={d}] values: ", .{new_slice.start, new_slice.end});
                            for (new_slice.start..new_slice.end + 1) |j| {
                                std.debug.print("{d} ", .{self.array[j]});
                            }
                            std.debug.print("\n", .{});
                            
                            // Find the correct insertion point using binary search
                            var left: usize = 0;
                            var right: usize = self.slices.items.len;
                            
                            while (left < right) {
                                const mid = left + (right - left) / 2;
                                const curr_slice = self.slices.items[mid];
                                if (self.array[new_slice.start] < self.array[curr_slice.start]) {
                                    right = mid;
                                } else if (self.array[new_slice.start] == self.array[curr_slice.start]) {
                                    // If values are equal, order by end value
                                    if (self.array[new_slice.end] < self.array[curr_slice.end]) {
                                        right = mid;
                                    } else {
                                        left = mid + 1;
                                    }
                                } else {
                                    left = mid + 1;
                                }
                            }
                            
                            // Insert at the correct position
                            self.slices.insert(left, new_slice) catch return false;
                        }
                        
                        std.debug.print("Final slice state:\n", .{});
                        for (self.slices.items, 0..) |s, slice_num| {
                            std.debug.print("  Slice {d}: [{d}..={d}] values: ", .{slice_num, s.start, s.end});
                            for (s.start..s.end + 1) |j| {
                                std.debug.print("{d} ", .{self.array[j]});
                            }
                            std.debug.print("\n", .{});
                        }
                    }
                    break;
                }
                slice_idx += 1;
            }
            
            std.debug.print("=== End modify ===\n", .{});
            return true;
        }

        /// Returns a sorted array based on the current slices
        pub fn sortedArray(self: *const Self) []T {
            var result = self.allocator.alloc(T, self.array.len) catch return &[_]T{};
            var count: usize = 0;

            for (self.slices.items) |slice| {
                const slice_len = slice.end - slice.start + 1;
                
                // Copy values from this slice directly to result
                for (0..slice_len) |i| {
                    if (count >= result.len) break;
                    result[count] = self.array[slice.start + i];
                    count += 1;
                }
            }

            return result;
        }
    };
}

/// Finds the correct position for a value in a sorted array using binary search
pub fn findCorrectPosition(comptime T: type, arr: []const T, value: T, start: usize, end: usize) usize {
    var left = start;
    var right = end;
    
    while (left <= right) {
        const mid = left + (right - left) / 2;
        
        if (arr[mid] == value) {
            return mid;
        } else if (arr[mid] < value) {
            left = mid + 1;
        } else {
            if (mid == 0) break;
            right = mid - 1;
        }
    }
    
    return left;
}

/// Finds the index of a value in a sorted array using binary search
pub fn findIndex(comptime T: type, arr: []const T, value: T) ?usize {
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

/// Fixes a mostly sorted sequence with exactly two out-of-order elements
/// Returns the sorted sequence if successful, null if the sequence cannot be fixed
pub fn fixMostlySorted(comptime T: type, seq: *SortedSequence(T), index1: usize, index2: usize) !?SortedSequence(T) {
    if (seq.array.len < 2) return null;
    if (index1 >= seq.array.len or index2 >= seq.array.len) return null;
    if (index1 == index2) return null;

    std.debug.print("\n=== Starting fixMostlySorted ===\n", .{});
    std.debug.print("Input array: ", .{});
    for (0..seq.array.len) |i| {
        std.debug.print("{d} ", .{seq.array[i]});
    }
    std.debug.print("\nIndices to fix: {d}, {d}\n", .{index1, index2});

    // Create a new sorted sequence
    var new_seq = try SortedSequence(T).init(seq.allocator, seq.array.len);

    // Copy all values except the out-of-order ones
    for (0..seq.array.len) |i| {
        if (i != index1 and i != index2) {
            const success = new_seq.modify(i, seq.array[i], seq.array[i]);
            std.debug.print("Copying index {d}: value {d} (success: {})\n", .{i, seq.array[i], success});
        }
    }

    // Add the two out-of-order elements in the correct order
    const val1 = seq.array[index1];
    const val2 = seq.array[index2];
    
    std.debug.print("Out-of-order values: {d}, {d}\n", .{val1, val2});
    
    // Add smaller value first to avoid losing values
    if (val1 < val2) {
        const success1 = new_seq.modify(index1, new_seq.array[index1], val1);
        const success2 = new_seq.modify(index2, new_seq.array[index2], val2);
        std.debug.print("Adding smaller first: index1={d} ({d}), index2={d} ({d})\n", .{index1, val1, index2, val2});
        std.debug.print("Modify success: {d} -> {}, {d} -> {}\n", .{index1, success1, index2, success2});
    } else {
        const success2 = new_seq.modify(index2, new_seq.array[index2], val2);
        const success1 = new_seq.modify(index1, new_seq.array[index1], val1);
        std.debug.print("Adding smaller first: index2={d} ({d}), index1={d} ({d})\n", .{index2, val2, index1, val1});
        std.debug.print("Modify success: {d} -> {}, {d} -> {}\n", .{index2, success2, index1, success1});
    }

    std.debug.print("=== End fixMostlySorted ===\n", .{});
    return new_seq;
}

/// Returns true if n is a power of 2
fn isPowerOfTwo(n: u64) bool {
    return n > 0 and (n & (n - 1)) == 0;
}

/// Returns true if n is a power of 4
fn isPowerOfFour(n: u64) bool {
    return isPowerOfTwo(n) and (n & 0xAAAAAAAAAAAAAAAA) == 0;
}

test "fix mostly sorted array" {
    const testing = std.testing;

     // Test case 1: Simple case
    var seq1 = try SortedSequence(u64).init(std.heap.page_allocator, 5);
    defer seq1.deinit();

    // Modify values to create [1, 2, 4, 3, 5]
    _ = seq1.modify(2, 3, 4);
    _ = seq1.modify(3, 4, 3);
    
    const sorted1 = seq1.sortedArray();
    defer seq1.allocator.free(sorted1);
    
    try testing.expectEqualSlices(u64, &[_]u64{ 1, 2, 3, 4, 5 }, sorted1);
    
    // Test case 2: Elements far apart
    var seq2 = try SortedSequence(u64).init(std.heap.page_allocator, 5);
    defer seq2.deinit();

    // Modify values to create [1, 2, 5, 4, 3]
    _ = seq2.modify(2, 3, 5);
    _ = seq2.modify(3, 4, 4);
    _ = seq2.modify(4, 5, 3);
    
    const sorted2 = seq2.sortedArray();
    defer seq2.allocator.free(sorted2);
    
    try testing.expectEqualSlices(u64, &[_]u64{ 1, 2, 3, 4, 5 }, sorted2);
    
    // Test case 3: Edge case with first and last elements
    var seq3 = try SortedSequence(u64).init(std.heap.page_allocator, 5);
    defer seq3.deinit();

    // Modify values to create [5, 2, 3, 4, 1]
    _ = seq3.modify(0, 1, 5);
    _ = seq3.modify(4, 5, 1);
    
    const sorted3 = seq3.sortedArray();
    defer seq3.allocator.free(sorted3);
    
    try testing.expectEqualSlices(u64, &[_]u64{ 1, 2, 3, 4, 5 }, sorted3);

    // Test case 4: Array with duplicate values
    var seq4 = try SortedSequence(u64).init(std.heap.page_allocator, 10);
    defer seq4.deinit();

    // Modify values to create [3, 2, 3, 4, 5, 6, 7, 8, 3, 10]
    _ = seq4.modify(0, 1, 3);
    _ = seq4.modify(1, 2, 2);
    _ = seq4.modify(8, 9, 3);
    
    const sorted4 = seq4.sortedArray();
    defer seq4.allocator.free(sorted4);
    
    try testing.expectEqualSlices(u64, &[_]u64{ 2, 3, 3, 3, 4, 5, 6, 7, 8, 10 }, sorted4);
}

