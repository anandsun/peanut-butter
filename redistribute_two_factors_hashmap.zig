const std = @import("std");
const MinHoleHashMap = @import("min_hole_hash_map.zig").MinHoleHashMap;

pub fn redistributeTwoFactors(n: u64) ![]u64 {
    // Create a hash map
    var hash_map = MinHoleHashMap.init(std.heap.page_allocator);
    defer hash_map.deinit();

    // Calculate the starting point (3n/8 rounded up to nearest even number)
    const lower_bound = (3 * n) / 8;
    const start = if (lower_bound % 2 == 0) lower_bound + 2 else lower_bound + 1;
    
    // Loop over even integers from start to n
    var i: u64 = start;
    while (i <= n) : (i += 2) {
        const i_half = i / 2;
        try hash_map.add(i, i_half);
        try hash_map.doubleMinValue();

        if (i_half % 2 == 0 and i_half > lower_bound) {
            try hash_map.add(i, i / 4);
            try hash_map.doubleMinValue();
        }
    }

    // Create array of integers from 1 to n
    var arr = try std.heap.page_allocator.alloc(u64, n);
    for (0..n) |x| {
        const value = @as(u64, x + 1);
        arr[x] = if (hash_map.get(value)) |v| v else value;
    }

    // Sort the array
    std.sort.insertion(u64, arr, {}, std.sort.asc(u64));

    return arr;
}

test "redistribute two factors - N=15" {
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
