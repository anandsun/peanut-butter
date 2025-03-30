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
            
            // Find the slice containing the modified index
            var slice_idx: usize = 0;
            while (slice_idx < self.slices.items.len) {
                const slice = self.slices.items[slice_idx];
                if (index >= slice.start and index <= slice.end) {
                    // Value is within this slice
                    var is_out_of_order = false;
                    var slice_to_split: ?usize = null;
                    var split_value: T = new_value;
                    
                    // Check if value is out of order with respect to immediate neighbors
                    // First check left neighbor
                    if (index > slice.start) {
                        // Check against element to the left within same slice
                        if (self.array[index] < self.array[index - 1]) {
                            is_out_of_order = true;
                            slice_to_split = slice_idx;
                            split_value = self.array[index - 1];
                        }
                    } else if (slice_idx > 0) {
                        // Check against rightmost element of previous slice
                        const prev_slice = self.slices.items[slice_idx - 1];
                        if (self.array[index] < self.array[prev_slice.end]) {
                            is_out_of_order = true;
                            slice_to_split = slice_idx - 1;
                            split_value = self.array[prev_slice.end];
                        }
                    }
                    
                    // Then check right neighbor
                    if (!is_out_of_order) {
                        if (index < slice.end) {
                            // Check against element to the right within same slice
                            if (self.array[index] > self.array[index + 1]) {
                                is_out_of_order = true;
                                slice_to_split = slice_idx;
                                split_value = self.array[index + 1];
                            }
                        } else if (slice_idx < self.slices.items.len - 1) {
                            // Check against leftmost element of next slice
                            const next_slice = self.slices.items[slice_idx + 1];
                            if (self.array[index] > self.array[next_slice.start]) {
                                is_out_of_order = true;
                                slice_to_split = slice_idx + 1;
                                split_value = self.array[next_slice.start];
                            }
                        }
                    }
                    
                    if (is_out_of_order) {
                        // First split the appropriate slice
                        const split_slice = self.slices.items[slice_to_split.?];
                        const split_idx = findCorrectPosition(T, self.array, split_value, split_slice.start, split_slice.end);
                        
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
                        
                        // After inserting all new slices, check if any of them are singletons and split others if needed
                        var new_slice_idx: usize = 0;
                        while (new_slice_idx < new_slices.items.len) {
                            const new_slice = new_slices.items[new_slice_idx];
                            if (new_slice.start == new_slice.end) {  // This is a singleton slice
                                const singleton_value = self.array[new_slice.start];
                                
                                // Check all existing slices
                                var existing_slice_idx: usize = 0;
                                while (existing_slice_idx < self.slices.items.len) {
                                    const existing_slice = self.slices.items[existing_slice_idx];
                                    const slice_start_val = self.array[existing_slice.start];
                                    const slice_end_val = self.array[existing_slice.end];
                                    
                                    // If this slice contains values both less than and greater than the singleton
                                    if (slice_start_val < singleton_value and slice_end_val > singleton_value) {
                                        // Find where to split this slice
                                        const singleton_split_idx = findCorrectPosition(T, self.array, singleton_value, existing_slice.start, existing_slice.end);
                                        
                                        // Remove the slice that needs to be split
                                        _ = self.slices.orderedRemove(existing_slice_idx);
                                        
                                        // Add the split parts in the correct order
                                        if (singleton_split_idx > existing_slice.start) {
                                            // Find correct insertion position for first part
                                            var left: usize = 0;
                                            var right: usize = self.slices.items.len;
                                            while (left < right) {
                                                const mid = left + (right - left) / 2;
                                                const curr_slice = self.slices.items[mid];
                                                if (self.array[existing_slice.start] < self.array[curr_slice.start]) {
                                                    right = mid;
                                                } else if (self.array[existing_slice.start] == self.array[curr_slice.start]) {
                                                    // If values are equal, order by end value
                                                    if (self.array[existing_slice.end] < self.array[curr_slice.end]) {
                                                        right = mid;
                                                    } else {
                                                        left = mid + 1;
                                                    }
                                                } else {
                                                    left = mid + 1;
                                                }
                                            }
                                            self.slices.insert(left, .{
                                                .start = existing_slice.start,
                                                .end = singleton_split_idx - 1,
                                            }) catch return false;
                                        }
                                        
                                        if (singleton_split_idx <= existing_slice.end) {
                                            // Find correct insertion position for second part
                                            var left: usize = 0;
                                            var right: usize = self.slices.items.len;
                                            while (left < right) {
                                                const mid = left + (right - left) / 2;
                                                const curr_slice = self.slices.items[mid];
                                                if (self.array[singleton_split_idx] < self.array[curr_slice.start]) {
                                                    right = mid;
                                                } else if (self.array[singleton_split_idx] == self.array[curr_slice.start]) {
                                                    // If values are equal, order by end value
                                                    if (self.array[existing_slice.end] < self.array[curr_slice.end]) {
                                                        right = mid;
                                                    } else {
                                                        left = mid + 1;
                                                    }
                                                } else {
                                                    left = mid + 1;
                                                }
                                            }
                                            self.slices.insert(left, .{
                                                .start = singleton_split_idx,
                                                .end = existing_slice.end,
                                            }) catch return false;
                                        }
                                        
                                        // Since we modified the slice array, we need to check this position again
                                        existing_slice_idx -= 1;
                                    }
                                    existing_slice_idx += 1;
                                }
                            }
                            new_slice_idx += 1;
                        }
                    }
                    break;
                }
                slice_idx += 1;
            }
            
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

test "simple case - two adjacent elements swapped" {
    const testing = std.testing;

    var seq = try SortedSequence(u64).init(std.heap.page_allocator, 5);
    defer seq.deinit();

    // Modify values to create [1, 2, 4, 3, 5]
    _ = seq.modify(2, 3, 4);
    _ = seq.modify(3, 4, 3);
    
    const sorted = seq.sortedArray();
    defer seq.allocator.free(sorted);
    
    try testing.expectEqualSlices(u64, &[_]u64{ 1, 2, 3, 4, 5 }, sorted);
}

test "elements far apart - multiple modifications" {
    const testing = std.testing;

    var seq = try SortedSequence(u64).init(std.heap.page_allocator, 5);
    defer seq.deinit();

    // Modify values to create [1, 2, 5, 4, 3]
    _ = seq.modify(2, 3, 5);
    _ = seq.modify(4, 5, 3);
    
    const sorted = seq.sortedArray();
    defer seq.allocator.free(sorted);
    
    try testing.expectEqualSlices(u64, &[_]u64{ 1, 2, 3, 4, 5 }, sorted);
}

test "edge case - first and last elements swapped" {
    const testing = std.testing;

    var seq = try SortedSequence(u64).init(std.heap.page_allocator, 5);
    defer seq.deinit();

    // Modify values to create [5, 2, 3, 4, 1]
    _ = seq.modify(0, 1, 5);
    _ = seq.modify(4, 5, 1);
    
    const sorted = seq.sortedArray();
    defer seq.allocator.free(sorted);
    
    try testing.expectEqualSlices(u64, &[_]u64{ 1, 2, 3, 4, 5 }, sorted);
}

test "array with duplicate values" {
    const testing = std.testing;

    var seq = try SortedSequence(u64).init(std.heap.page_allocator, 10);
    defer seq.deinit();

    // Modify values to create [3, 2, 3, 4, 5, 6, 7, 8, 3, 10]
    _ = seq.modify(0, 1, 3);
    _ = seq.modify(8, 9, 3);
    
    const sorted = seq.sortedArray();
    defer seq.allocator.free(sorted);
    
    try testing.expectEqualSlices(u64, &[_]u64{ 2, 3, 3, 3, 4, 5, 6, 7, 8, 10 }, sorted);
}

test "simulating mid way through processing the redistribute 2 factors algorithm on input 15" {
    const testing = std.testing;

    var seq = try SortedSequence(u64).init(std.heap.page_allocator, 15);
    defer seq.deinit();

    // Simulate redistributing the 2s from 6 and 8 to smaller elements
    _ = seq.modify(5, 6, 3);
    _ = seq.modify(0, 1, 2);
    _ = seq.modify(7, 8, 4);
    _ = seq.modify(0, 2, 4);

    const sorted = seq.sortedArray();
    defer seq.allocator.free(sorted);
    
    // The expected result should be properly sorted
    try testing.expectEqualSlices(u64, &[_]u64{ 2, 3, 3, 4, 4, 4, 5, 7, 9, 10, 11, 12, 13, 14, 15 }, sorted);
}

test "simulating mid way through processing the redistribute 2 factors algorithm on input 15, more steps" {
    const testing = std.testing;

    var seq = try SortedSequence(u64).init(std.heap.page_allocator, 15);
    defer seq.deinit();

    // Simulate redistributing the 2s from 6 and 8 to smaller elements
    _ = seq.modify(5, 6, 3);
    _ = seq.modify(0, 1, 2);
    _ = seq.modify(7, 8, 4);
    _ = seq.modify(0, 2, 4);
    _ = seq.modify(9, 10, 5);
    _ = seq.modify(1, 2, 4);

    const sorted = seq.sortedArray();
    defer seq.allocator.free(sorted);
    
    // The expected result should be properly sorted
    try testing.expectEqualSlices(u64, &[_]u64{ 3, 3, 4, 4, 4, 4, 5, 5, 7, 9, 11, 12, 13, 14, 15 }, sorted);
}
