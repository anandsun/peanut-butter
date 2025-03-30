const std = @import("std");

/// Represents a contiguous range of indices that are in sorted order
const Range = struct {
    start: usize,
    end: usize,
    next: ?*Range,
};

/// Represents a sorted sequence by tracking contiguous ranges of sorted indices
fn SortedSequence(comptime T: type) type {
    return struct {
        const Self = @This();
        
        /// Original array we're sorting
        original_array: []T,
        /// First range in the linked list
        first_range: ?*Range,
        /// Allocator for ranges
        allocator: std.mem.Allocator,

        pub fn init(allocator: std.mem.Allocator, arr: []T) !Self {
            return Self{
                .original_array = arr,
                .first_range = null,
                .allocator = allocator,
            };
        }

        pub fn deinit(self: *Self) void {
            var current = self.first_range;
            while (current) |range| {
                const next = range.next;
                self.allocator.destroy(range);
                current = next;
            }
        }

        /// Returns the value at the given sorted position
        fn valueAt(self: *const Self, index: usize) T {
            var current = self.first_range;
            var current_index: usize = 0;
            
            while (current) |range| {
                const range_len = range.end - range.start + 1;
                if (current_index + range_len > index) {
                    const offset = index - current_index;
                    return self.original_array[range.start + offset];
                }
                current_index += range_len;
                current = range.next;
            }
            
            unreachable;
        }

        /// Tries to merge adjacent ranges if they represent consecutive indices
        fn tryMergeRanges(self: *Self) void {
            var current = self.first_range;
            while (current) |range| {
                while (range.next) |next| {
                    // Check if ranges can be merged (consecutive indices and values)
                    if (range.end + 1 == next.start and 
                        self.original_array[range.end] + 1 == self.original_array[next.start]) {
                        // Merge ranges
                        range.end = next.end;
                        range.next = next.next;
                        self.allocator.destroy(next);
                    } else {
                        break;
                    }
                }
                current = range.next;
            }
        }

        /// Adds an element to the sequence, maintaining sorted order
        pub fn add(self: *Self, index: usize, value: T) void {
            // Create new range for this element
            const new_range = self.allocator.create(Range) catch return;
            new_range.* = .{
                .start = index,
                .end = index,
                .next = null,
            };

            // If list is empty, make this the first range
            if (self.first_range == null) {
                self.first_range = new_range;
                return;
            }

            // Special case: if value is smaller than first range
            if (value < self.original_array[self.first_range.?.start]) {
                new_range.next = self.first_range;
                self.first_range = new_range;
                self.tryMergeRanges();
                return;
            }

            // Find where to insert based on value
            var prev: ?*Range = null;
            var current = self.first_range;
            
            while (current) |range| {
                const current_value = self.original_array[range.start];
                const next_value = if (range.next) |next| self.original_array[next.start] else value + 1;
                
                if (value < current_value) {
                    // Insert before current range
                    if (prev) |p| {
                        new_range.next = p.next;
                        p.next = new_range;
                    } else {
                        new_range.next = self.first_range;
                        self.first_range = new_range;
                    }
                    self.tryMergeRanges();
                    return;
                } else if (value < next_value) {
                    // Insert after current range
                    new_range.next = range.next;
                    range.next = new_range;
                    self.tryMergeRanges();
                    return;
                }
                
                prev = range;
                current = range.next;
            }
            
            // If we get here, append to the end
            if (prev) |p| {
                p.next = new_range;
                self.tryMergeRanges();
            }
        }

        /// Returns the total length of the sequence
        fn len(self: *const Self) usize {
            var total: usize = 0;
            var current = self.first_range;
            while (current) |range| {
                total += range.end - range.start + 1;
                current = range.next;
            }
            return total;
        }

        /// Copies the sorted sequence back to the array
        pub fn copyToArray(self: *const Self, arr: []T) void {
            // First, create a mapping of indices to their values
            var indices = self.allocator.alloc(usize, arr.len) catch return;
            defer self.allocator.free(indices);
            
            var values = self.allocator.alloc(T, arr.len) catch return;
            defer self.allocator.free(values);
            
            var count: usize = 0;
            
            // Collect all indices and values
            var current = self.first_range;
            while (current) |range| {
                const range_len = range.end - range.start + 1;
                for (0..range_len) |i| {
                    indices[count] = range.start + i;
                    values[count] = self.original_array[range.start + i];
                    count += 1;
                }
                current = range.next;
            }
            
            // Sort indices based on values using insertion sort
            for (1..count) |i| {
                const key_value = values[i];
                const key_index = indices[i];
                var j = i;
                
                while (j > 0 and values[j - 1] > key_value) : (j -= 1) {
                    values[j] = values[j - 1];
                    indices[j] = indices[j - 1];
                }
                
                values[j] = key_value;
                indices[j] = key_index;
            }
            
            // Copy values in sorted order
            for (0..count) |i| {
                arr[i] = values[i];
            }
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

/// Fixes a mostly sorted array with exactly two out-of-order elements
/// Returns true if successful, false if the array cannot be fixed
pub fn fixMostlySorted(comptime T: type, arr: []T, index1: usize, index2: usize) !bool {
    if (arr.len < 2) return false;
    if (index1 >= arr.len or index2 >= arr.len) return false;
    if (index1 == index2) return false;

    // Create a sorted sequence to track the order
    var seq = try SortedSequence(T).init(std.heap.page_allocator, arr);
    defer seq.deinit();

    // Add all elements except the out-of-order ones
    for (0..arr.len) |i| {
        if (i != index1 and i != index2) {
            seq.add(i, arr[i]);
        }
    }

    // Add the two out-of-order elements in the correct order
    const val1 = arr[index1];
    const val2 = arr[index2];
    
    // Add larger value first
    if (val1 > val2) {
        seq.add(index1, val1);
        seq.add(index2, val2);
    } else {
        seq.add(index2, val2);
        seq.add(index1, val1);
    }

    // Copy the sorted sequence back to the array
    seq.copyToArray(arr);
    return true;
}

/// Returns true if n is a power of 2
fn isPowerOfTwo(n: u64) bool {
    return n > 0 and (n & (n - 1)) == 0;
}

/// Returns true if n is a power of 4
fn isPowerOfFour(n: u64) bool {
    return isPowerOfTwo(n) and (n & 0xAAAAAAAAAAAAAAAA) == 0;
}

/// Processes powers of 2 in the array according to the specified rules
pub fn processPowersOfTwo(n: u64) ![]u64 {
    // Create array of integers from 1 to N
    var arr = try std.heap.page_allocator.alloc(u64, n);
    for (0..n) |i| {
        arr[i] = @intCast(i + 1);
    }

    // Calculate the starting power of 2 (3N/8)
    const start_power = (3 * n) / 8;
    var current_power: u64 = 1;
    while (current_power < start_power) : (current_power *= 2) {}

    // Process each power of 2 up to N
    while (current_power <= n) : (current_power *= 2) {
        if (isPowerOfFour(current_power) and current_power > (3 * n) / 4) {
            if (findIndex(u64, arr, current_power)) |idx| {
                // Store original values
                const original_first = arr[0];
                const original_power = arr[idx];
                
                // First operation: divide power of 4 by 4
                arr[idx] = original_power / 4;
                
                // Second operation: multiply first element by 2
                arr[0] = original_first * 2;
                
                // Fix sorting after both operations
                _ = try fixMostlySorted(u64, arr, 0, idx);
                
                // Third operation: multiply first element by 2 again
                arr[0] *= 2;
                
                // Fix sorting again
                _ = try fixMostlySorted(u64, arr, 0, 1);
            }
        } else {
            if (findIndex(u64, arr, current_power)) |idx| {
                // Store original values
                const original_first = arr[0];
                const original_power = arr[idx];
                
                // First operation: divide power of 2 by 2
                arr[idx] = original_power / 2;
                
                // Second operation: multiply first element by 2
                arr[0] = original_first * 2;
                
                // Fix sorting after both operations
                _ = try fixMostlySorted(u64, arr, 0, idx);
            }
        }
    }

    return arr;
}

test "fix mostly sorted array" {
    const testing = std.testing;
    
    // Test case 1: Simple case
    var arr1 = [_]u64{ 1, 2, 4, 3, 5 };
    try testing.expect(try fixMostlySorted(u64, &arr1, 2, 3));
    try testing.expectEqualSlices(u64, &[_]u64{ 1, 2, 3, 4, 5 }, &arr1);
    
    // Test case 2: Elements far apart
    var arr2 = [_]u64{ 1, 2, 5, 4, 3 };
    try testing.expect(try fixMostlySorted(u64, &arr2, 2, 4));
    try testing.expectEqualSlices(u64, &[_]u64{ 1, 2, 3, 4, 5 }, &arr2);
    
    // Test case 3: Edge case with first and last elements
    var arr3 = [_]u64{ 5, 2, 3, 4, 1 };
    try testing.expect(try fixMostlySorted(u64, &arr3, 0, 4));
    try testing.expectEqualSlices(u64, &[_]u64{ 1, 2, 3, 4, 5 }, &arr3);

    // Test case 4: Array with duplicate values
    var arr4 = [_]u64{ 3, 2, 3, 4, 5, 6, 7, 8, 3, 10 };
    try testing.expect(try fixMostlySorted(u64, &arr4, 0, 8));
    try testing.expectEqualSlices(u64, &[_]u64{ 2, 3, 3, 3, 4, 5, 6, 7, 8, 10 }, &arr4);
}
