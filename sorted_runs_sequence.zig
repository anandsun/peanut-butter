const std = @import("std");

/// Represents a position of a sorted run in the array
const RunPosition = struct {
    start: usize,
    end: usize,
};

/// Represents a sequence by tracking positions of sorted runs
pub fn SortedRunsSequence(comptime T: type) type {
    return struct {
        const Self = @This();
        
        /// Array containing the values
        array: []T,
        /// Dynamic array of sorted runs
        runs: std.ArrayList(RunPosition),
        /// Allocator for runs
        allocator: std.mem.Allocator,

        pub fn init(allocator: std.mem.Allocator, n: usize) !Self {
            // Create array of integers from 1 to N
            var arr = try allocator.alloc(T, n);
            for (0..n) |i| {
                arr[i] = @intCast(i + 1);
            }

            // Create initial run covering entire array
            var runs = std.ArrayList(RunPosition).init(allocator);
            try runs.append(.{
                .start = 0,
                .end = n - 1,
            });

            return Self{
                .array = arr,
                .runs = runs,
                .allocator = allocator,
            };
        }

        pub fn deinit(self: *Self) void {
            self.runs.deinit();
            self.allocator.free(self.array);
        }

        /// Returns the value at the given index in the underlying array
        pub fn valueAt(self: *const Self, index: usize) T {
            return self.array[index];
        }

        /// Returns the index of the minimum value in the sequence
        pub fn minimumIndex(self: *const Self) usize {
            return self.runs.items[0].start;
        }

        /// Modifies a value at the given index if it matches the expected value
        pub fn modify(self: *Self, index: usize, expected_value: T, new_value: T) bool {
            if (self.array[index] != expected_value) {
                return false;
            }
            self.array[index] = new_value;
            
            // Find the run containing the modified index
            var run_idx: usize = 0;
            while (run_idx < self.runs.items.len) {
                const run = self.runs.items[run_idx];
                if (index >= run.start and index <= run.end) {
                    // Value is within this run
                    var is_out_of_order = false;
                    var run_to_split: ?usize = null;
                    var split_value: T = new_value;
                    
                    // Check if value is out of order with respect to immediate neighbors
                    // First check left neighbor
                    if (index > run.start) {
                        // Check against element to the left within same run
                        if (self.array[index] < self.array[index - 1]) {
                            is_out_of_order = true;
                            run_to_split = run_idx;
                            split_value = self.array[index - 1];
                        }
                    } else if (run_idx > 0) {
                        // Check against rightmost element of previous run
                        const prev_run = self.runs.items[run_idx - 1];
                        if (self.array[index] < self.array[prev_run.end]) {
                            is_out_of_order = true;
                            run_to_split = run_idx - 1;
                            split_value = self.array[prev_run.end];
                        }
                    }
                    
                    // Then check right neighbor
                    if (!is_out_of_order) {
                        if (index < run.end) {
                            // Check against element to the right within same run
                            if (self.array[index] > self.array[index + 1]) {
                                is_out_of_order = true;
                                run_to_split = run_idx;
                                split_value = self.array[index + 1];
                            }
                        } else if (run_idx < self.runs.items.len - 1) {
                            // Check against leftmost element of next run
                            const next_run = self.runs.items[run_idx + 1];
                            if (self.array[index] > self.array[next_run.start]) {
                                is_out_of_order = true;
                                run_to_split = run_idx + 1;
                                split_value = self.array[next_run.start];
                            }
                        }
                    }
                    
                    if (is_out_of_order) {
                        // First split the appropriate run
                        const split_run = self.runs.items[run_to_split.?];
                        const split_idx = findCorrectPosition(T, self.array, split_value, split_run.start, split_run.end);
                        
                        // Remove the original run
                        _ = self.runs.orderedRemove(run_to_split.?);
                        
                        // Collect all new runs we need to insert
                        var new_runs = std.ArrayList(RunPosition).init(self.allocator);
                        defer new_runs.deinit();
                        
                        // Add the split runs from the first split
                        if (split_idx > split_run.start) {
                            new_runs.append(.{
                                .start = split_run.start,
                                .end = split_idx - 1,
                            }) catch return false;
                        }
                        
                        if (split_idx <= split_run.end) {
                            new_runs.append(.{
                                .start = split_idx,
                                .end = split_run.end,
                            }) catch return false;
                        }

                        // If our run is a singleton, we should replace it too
                        if (run.start == run.end and run_to_split.? != run_idx) {
                            // Because we already removed run_to_split above, it may affect the index we process here
                            const our_run_index = if (run_to_split.? < run_idx) run_idx - 1 else run_idx;
                            _ = self.runs.orderedRemove(our_run_index);
                            new_runs.append(.{
                                .start = index,
                                .end = index,
                            }) catch return false;
                        }
                        
                        // If the run we just split contains our modified value's index,
                        // we need to split it again at that index
                        if (index >= split_run.start and index <= split_run.end) {
                            // Find which of the new runs contains our index
                            for (new_runs.items, 0..) |new_run, i| {
                                if (index >= new_run.start and index <= new_run.end) {
                                    // Remove this run from new_runs
                                    _ = new_runs.orderedRemove(i);
                                    
                                    // Add the split runs
                                    if (index > new_run.start) {
                                        new_runs.append(.{
                                            .start = new_run.start,
                                            .end = index - 1,
                                        }) catch return false;
                                    }
                                    
                                    new_runs.append(.{
                                        .start = index,
                                        .end = index,
                                    }) catch return false;
                                    
                                    if (index + 1 <= new_run.end) {
                                        new_runs.append(.{
                                            .start = index + 1,
                                            .end = new_run.end,
                                        }) catch return false;
                                    }
                                    break;
                                }
                            }
                        }
                        
                        // Check if any of the new runs need to be split further
                        var i: usize = 0;
                        while (i < new_runs.items.len) {
                            const curr_run = new_runs.items[i];
                            if (curr_run.start != curr_run.end) {  // Skip singleton runs
                                const run_start_val = self.array[curr_run.start];
                                const run_end_val = self.array[curr_run.end];
                                if (run_start_val < new_value and run_end_val > new_value) {
                                    // This run needs to be split
                                    const inner_split_idx = findCorrectPosition(T, self.array, new_value, curr_run.start, curr_run.end);
                                    
                                    // Remove the current run
                                    _ = new_runs.orderedRemove(i);
                                    
                                    // Add the split parts
                                    if (inner_split_idx > curr_run.start) {
                                        new_runs.insert(i, .{
                                            .start = curr_run.start,
                                            .end = inner_split_idx - 1,
                                        }) catch return false;
                                        i += 1;
                                    }
                                    
                                    if (inner_split_idx <= curr_run.end) {
                                        new_runs.insert(i, .{
                                            .start = inner_split_idx,
                                            .end = curr_run.end,
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
                        
                        // Insert all new runs in sorted order
                        for (new_runs.items) |new_run| {
                            // Find the correct insertion point using binary search
                            var left: usize = 0;
                            var right: usize = self.runs.items.len;
                            
                            while (left < right) {
                                const mid = left + (right - left) / 2;
                                const curr_run = self.runs.items[mid];
                                if (self.array[new_run.start] < self.array[curr_run.start]) {
                                    right = mid;
                                } else if (self.array[new_run.start] == self.array[curr_run.start]) {
                                    // If values are equal, order by end value
                                    if (self.array[new_run.end] < self.array[curr_run.end]) {
                                        right = mid;
                                    } else {
                                        left = mid + 1;
                                    }
                                } else {
                                    left = mid + 1;
                                }
                            }
                            
                            // Insert at the correct position
                            self.runs.insert(left, new_run) catch return false;
                        }
                        
                        // After inserting all new runs, check if any of them are singletons and split others if needed
                        var new_run_idx: usize = 0;
                        while (new_run_idx < new_runs.items.len) {
                            const new_run = new_runs.items[new_run_idx];
                            if (new_run.start == new_run.end) {  // This is a singleton run
                                const singleton_value = self.array[new_run.start];
                                
                                // Check all existing runs
                                var existing_run_idx: usize = 0;
                                while (existing_run_idx < self.runs.items.len) {
                                    const existing_run = self.runs.items[existing_run_idx];
                                    const run_start_val = self.array[existing_run.start];
                                    const run_end_val = self.array[existing_run.end];
                                    
                                    // If this run contains values both less than and greater than the singleton
                                    if (run_start_val < singleton_value and run_end_val > singleton_value) {
                                        // Find where to split this run
                                        const singleton_split_idx = findCorrectPosition(T, self.array, singleton_value, existing_run.start, existing_run.end);
                                        
                                        // Remove the run that needs to be split
                                        _ = self.runs.orderedRemove(existing_run_idx);
                                        
                                        // Add the split parts in the correct order
                                        if (singleton_split_idx > existing_run.start) {
                                            // Find correct insertion position for first part
                                            var left: usize = 0;
                                            var right: usize = self.runs.items.len;
                                            while (left < right) {
                                                const mid = left + (right - left) / 2;
                                                const curr_run = self.runs.items[mid];
                                                if (self.array[existing_run.start] < self.array[curr_run.start]) {
                                                    right = mid;
                                                } else if (self.array[existing_run.start] == self.array[curr_run.start]) {
                                                    // If values are equal, order by end value
                                                    if (self.array[existing_run.end] < self.array[curr_run.end]) {
                                                        right = mid;
                                                    } else {
                                                        left = mid + 1;
                                                    }
                                                } else {
                                                    left = mid + 1;
                                                }
                                            }
                                            self.runs.insert(left, .{
                                                .start = existing_run.start,
                                                .end = singleton_split_idx - 1,
                                            }) catch return false;
                                        }
                                        
                                        if (singleton_split_idx <= existing_run.end) {
                                            // Find correct insertion position for second part
                                            var left: usize = 0;
                                            var right: usize = self.runs.items.len;
                                            while (left < right) {
                                                const mid = left + (right - left) / 2;
                                                const curr_run = self.runs.items[mid];
                                                if (self.array[singleton_split_idx] < self.array[curr_run.start]) {
                                                    right = mid;
                                                } else if (self.array[singleton_split_idx] == self.array[curr_run.start]) {
                                                    // If values are equal, order by end value
                                                    if (self.array[existing_run.end] < self.array[curr_run.end]) {
                                                        right = mid;
                                                    } else {
                                                        left = mid + 1;
                                                    }
                                                } else {
                                                    left = mid + 1;
                                                }
                                            }
                                            self.runs.insert(left, .{
                                                .start = singleton_split_idx,
                                                .end = existing_run.end,
                                            }) catch return false;
                                        }
                                        
                                        // Since we modified the run array, we need to check this position again
                                        existing_run_idx -= 1;
                                    }
                                    existing_run_idx += 1;
                                }
                            }
                            new_run_idx += 1;
                        }
                    }
                    break;
                }
                run_idx += 1;
            }
            
            return true;
        }

        /// Returns a sorted array based on the current runs
        pub fn sortedArray(self: *const Self) []T {
            var result = self.allocator.alloc(T, self.array.len) catch return &[_]T{};
            var count: usize = 0;

            for (self.runs.items) |run| {
                const run_len = run.end - run.start + 1;
                
                // Copy values from this run directly to result
                for (0..run_len) |i| {
                    if (count >= result.len) break;
                    result[count] = self.array[run.start + i];
                    count += 1;
                }
            }

            return result;
        }
    };
}

/// Finds the correct position for a value in a sorted array using binary search
fn findCorrectPosition(comptime T: type, arr: []const T, value: T, start: usize, end: usize) usize {
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

test "simple case - two adjacent elements swapped" {
    var seq = try SortedRunsSequence(u64).init(std.heap.page_allocator, 5);
    defer seq.deinit();

    // Modify values to create [1, 2, 4, 3, 5]
    _ = seq.modify(2, 3, 4);
    _ = seq.modify(3, 4, 3);
    
    const sorted = seq.sortedArray();
    defer seq.allocator.free(sorted);
    
    try std.testing.expectEqualSlices(u64, &[_]u64{ 1, 2, 3, 4, 5 }, sorted);
}

test "elements far apart - multiple modifications" {
    var seq = try SortedRunsSequence(u64).init(std.heap.page_allocator, 5);
    defer seq.deinit();

    // Modify values to create [1, 2, 5, 4, 3]
    _ = seq.modify(2, 3, 5);
    _ = seq.modify(4, 5, 3);
    
    const sorted = seq.sortedArray();
    defer seq.allocator.free(sorted);
    
    try std.testing.expectEqualSlices(u64, &[_]u64{ 1, 2, 3, 4, 5 }, sorted);
}

test "edge case - first and last elements swapped" {
    var seq = try SortedRunsSequence(u64).init(std.heap.page_allocator, 5);
    defer seq.deinit();

    // Modify values to create [5, 2, 3, 4, 1]
    _ = seq.modify(0, 1, 5);
    _ = seq.modify(4, 5, 1);
    
    const sorted = seq.sortedArray();
    defer seq.allocator.free(sorted);
    
    try std.testing.expectEqualSlices(u64, &[_]u64{ 1, 2, 3, 4, 5 }, sorted);
}

test "array with duplicate values" {
    var seq = try SortedRunsSequence(u64).init(std.heap.page_allocator, 10);
    defer seq.deinit();

    // Modify values to create [3, 2, 3, 4, 5, 6, 7, 8, 3, 10]
    _ = seq.modify(0, 1, 3);
    _ = seq.modify(8, 9, 3);
    
    const sorted = seq.sortedArray();
    defer seq.allocator.free(sorted);
    
    try std.testing.expectEqualSlices(u64, &[_]u64{ 2, 3, 3, 3, 4, 5, 6, 7, 8, 10 }, sorted);
}

test "simulating mid way through processing the redistribute 2 factors algorithm on input 15" {
    var seq = try SortedRunsSequence(u64).init(std.heap.page_allocator, 15);
    defer seq.deinit();

    // Simulate redistributing the 2s from 6 and 8 to smaller elements
    _ = seq.modify(5, 6, 3);
    _ = seq.modify(0, 1, 2);
    _ = seq.modify(7, 8, 4);
    _ = seq.modify(0, 2, 4);

    const sorted = seq.sortedArray();
    defer seq.allocator.free(sorted);
    
    // The expected result should be properly sorted
    try std.testing.expectEqualSlices(u64, &[_]u64{ 2, 3, 3, 4, 4, 4, 5, 7, 9, 10, 11, 12, 13, 14, 15 }, sorted);
}

test "simulating mid way through processing the redistribute 2 factors algorithm on input 15, more steps" {
    var seq = try SortedRunsSequence(u64).init(std.heap.page_allocator, 15);
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
    try std.testing.expectEqualSlices(u64, &[_]u64{ 3, 3, 4, 4, 4, 4, 5, 5, 7, 9, 11, 12, 13, 14, 15 }, sorted);
}
