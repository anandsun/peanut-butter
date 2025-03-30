const std = @import("std");

/// Binary search to find the correct position for an element in a mostly sorted array
fn findPosition(comptime T: type, arr: []const T, elem: T, skip_indices: [2]usize, search_start: usize, search_end: usize) usize {
    var left = search_start;
    var right = search_end;
    
    while (left <= right) {
        const mid = left + (right - left) / 2;
        
        // Skip the indices we're trying to place
        if (mid == skip_indices[0] or mid == skip_indices[1]) {
            // Move to next position and try again
            left = mid + 1;
            continue;
        }
        
        if (arr[mid] >= elem) {
            if (mid == search_start) break;
            right = mid - 1;
        } else {
            left = mid + 1;
        }
    }
    
    // At this point, left is where we should insert the element
    // Adjust the position if it's one of the indices we're moving
    while (left == skip_indices[0] or left == skip_indices[1]) {
        left += 1;
    }
    
    // Ensure we don't go past the end of the array
    if (left > arr.len) {
        left = arr.len;
    }
    
    return left;
}

/// Moves a chunk of elements to their new position, handling the temporary storage
fn shiftChunk(comptime T: type, arr: []T, src_start: usize, src_end: usize, dest_start: usize, allocator: std.mem.Allocator) !void {
    if (src_start >= src_end) return;
    
    const chunk_size = src_end - src_start;
    const temp = try allocator.alloc(T, chunk_size);
    defer allocator.free(temp);
    
    // Save the elements we're moving
    @memcpy(temp, arr[src_start..src_end]);
    
    if (dest_start < src_start) {
        // Moving elements left, shift elements right to make space
        var i: usize = src_end - 1;
        while (i >= dest_start) : (i -= 1) {
            if (i == 0) break;
            arr[i] = arr[i - 1];
        }
        // Place the saved elements
        @memcpy(arr[dest_start..dest_start + chunk_size], temp);
    } else if (dest_start > src_start) {
        // Moving elements right, shift elements left to close gap
        var i: usize = src_start;
        while (i < dest_start) : (i += 1) {
            arr[i] = arr[i + 1];
        }
        // Place the saved elements
        @memcpy(arr[dest_start - 1..dest_start - 1 + chunk_size], temp);
    }
}

/// Fixes a mostly sorted array by moving two elements that are out of position.
/// Returns true if the array can be fixed, false otherwise.
pub fn fixMostlySorted(comptime T: type, arr: []T, i: usize, j: usize) !bool {
    const allocator = std.heap.page_allocator;
    
    // Extract the elements that need to be moved
    const elem_i = arr[i];
    const elem_j = arr[j];
    
    // Move first element (i)
    const skip_indices = [2]usize{ i, j };
    const pos_i = findPosition(T, arr, elem_i, skip_indices, i, j);
    
    // If moving right, first shift elements left to make space
    if (pos_i > i) {
        try shiftChunk(T, arr, i + 1, pos_i, i, allocator);
        arr[pos_i - 1] = elem_i;
    } else {
        // If moving left, shift elements right to make space
        try shiftChunk(T, arr, i, i + 1, pos_i, allocator);
    }
    
    // Adjust j's index if i was moved and affects j's position
    var adjusted_j = j;
    if (j > i) {
        if (pos_i > j) {
            // i was moved past j, so j moved back one position
            adjusted_j -= 1;
        }
    } else if (j < i) {
        if (pos_i <= j) {
            // i was moved before j, so j moved forward one position
            adjusted_j += 1;
        }
    }
    
    // Now find position for j in the modified array
    // For the second element, we need to search between the original positions of i and j,
    // but shifted based on how i's movement affected the array
    const search_start = if (pos_i > j) i else if (i > 0) i - 1 else 0;
    const search_end = if (pos_i > j) j - 1 else j;
    const skip_j = [2]usize{ adjusted_j, adjusted_j };
    const pos_j = findPosition(T, arr, elem_j, skip_j, search_start, search_end);
    
    // If moving right, first shift elements left to make space
    if (pos_j > adjusted_j) {
        try shiftChunk(T, arr, adjusted_j + 1, pos_j, adjusted_j, allocator);
        arr[pos_j - 1] = elem_j;
    } else {
        // If moving left, shift elements right to make space
        try shiftChunk(T, arr, adjusted_j, adjusted_j + 1, pos_j, allocator);
    }
    
    // Verify the result is sorted
    var k: usize = 1;
    while (k < arr.len) : (k += 1) {
        if (arr[k] < arr[k - 1]) {
            return false;
        }
    }
    
    return true;
}

test "simple case - adjacent elements swapped" {
    const testing = std.testing;
    
    var arr = [_]u64{ 1, 2, 4, 3, 5 };
    try testing.expect(try fixMostlySorted(u64, &arr, 2, 3));
    try testing.expectEqualSlices(u64, &[_]u64{ 1, 2, 3, 4, 5 }, &arr);
}

test "elements far apart - three elements shifted" {
    const testing = std.testing;
    
    var arr = [_]u64{ 1, 2, 5, 4, 3 };
    try testing.expect(try fixMostlySorted(u64, &arr, 2, 4));
    try testing.expectEqualSlices(u64, &[_]u64{ 1, 2, 3, 4, 5 }, &arr);
}

test "edge case - first and last elements swapped" {
    const testing = std.testing;
    
    var arr = [_]u64{ 5, 2, 3, 4, 1 };
    try testing.expect(try fixMostlySorted(u64, &arr, 0, 4));
    try testing.expectEqualSlices(u64, &[_]u64{ 1, 2, 3, 4, 5 }, &arr);
}

test "array with duplicate values at edges" {
    const testing = std.testing;
    
    var arr = [_]u64{ 3, 2, 3, 4, 5, 6, 7, 8, 3, 10 };
    try testing.expect(try fixMostlySorted(u64, &arr, 0, 8));
    try testing.expectEqualSlices(u64, &[_]u64{ 2, 3, 3, 3, 4, 5, 6, 7, 8, 10 }, &arr);
}

test "duplicate values between indices" {
    const testing = std.testing;
    
    var arr = [_]u64{ 4, 2, 3, 3, 4, 5, 7, 4, 9, 10, 11, 12, 13, 14, 15 };
    try testing.expect(try fixMostlySorted(u64, &arr, 0, 7));
    try testing.expectEqualSlices(u64, &[_]u64{ 2, 3, 3, 4, 4, 4, 5, 7, 9, 10, 11, 12, 13, 14, 15 }, &arr);
} 