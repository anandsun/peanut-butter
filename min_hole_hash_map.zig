const std = @import("std");

pub const MinValueResult = union(enum) {
    missing: u64,
    present: struct { index: u64, value: u64 },
};

const HeapNode = struct {
    value: u64,
    key: u64,
};

pub const MinHoleHashMap = struct {
    hash_map: std.AutoHashMap(u64, u64),
    min_hole: u64,
    min_heap: std.PriorityQueue(HeapNode, void, lessThan),

    pub fn init(allocator: std.mem.Allocator) MinHoleHashMap {
        return .{
            .hash_map = std.AutoHashMap(u64, u64).init(allocator),
            .min_hole = 1,
            .min_heap = std.PriorityQueue(HeapNode, void, lessThan).init(allocator, {}),
        };
    }

    pub fn deinit(self: *MinHoleHashMap) void {
        self.hash_map.deinit();
        self.min_heap.deinit();
    }

    fn lessThan(context: void, a: HeapNode, b: HeapNode) std.math.Order {
        _ = context;
        return std.math.order(a.value, b.value);
    }

    pub fn add(self: *MinHoleHashMap, key: u64, value: u64) !void {
        try self.hash_map.put(key, value);
        
        // Update min_hole if needed
        if (key == self.min_hole) {
            while (self.hash_map.contains(self.min_hole)) {
                self.min_hole += 1;
            }
        }

        // Add to min heap
        try self.min_heap.add(.{ .value = value, .key = key });
    }

    pub fn get(self: *const MinHoleHashMap, key: u64) ?u64 {
        return self.hash_map.get(key);
    }

    /// Finds either:
    /// 1. The smallest number from 1 to n that is not in the hash map
    /// 2. The smallest value bound to a key in the hash map and its index
    pub fn findMinValue(self: *MinHoleHashMap) MinValueResult {
        // Find smallest missing number
        const smallest_missing = self.min_hole;

        // If hash map is empty, return smallest missing
        if (self.min_heap.count() == 0) {
            return .{ .missing = smallest_missing };
        }

        // Get the minimum value from the heap
        const min_node = self.min_heap.peek().?;

        // Return the smaller of the two
        if (smallest_missing < min_node.value) {
            return .{ .missing = smallest_missing };
        } else {
            return .{ .present = .{ .index = min_node.key, .value = min_node.value } };
        }
    }

    /// Doubles the minimum value in the hash map, whether it's a missing value or a present value
    pub fn doubleMinValue(self: *MinHoleHashMap) !void {
        const min_result = self.findMinValue();
        switch (min_result) {
            .missing => |v| {
                try self.add(v, v * 2);
            },
            .present => |p| {
                // Create a new heap without the target element
                var new_heap = std.PriorityQueue(HeapNode, void, lessThan).init(self.min_heap.allocator, {});
                errdefer new_heap.deinit();

                // Copy all elements except the one we want to remove
                while (self.min_heap.count() > 0) {
                    const node = self.min_heap.remove();
                    if (node.key != p.index) {
                        try new_heap.add(node);
                    }
                }

                // Deinit old heap and replace with new one
                self.min_heap.deinit();
                self.min_heap = new_heap;

                // Add the doubled value
                try self.add(p.index, p.value * 2);
            },
        }
    }
};

test "MinHoleHashMap - basic operations" {
    var hash_map = MinHoleHashMap.init(std.heap.page_allocator);
    defer hash_map.deinit();

    try std.testing.expectEqual(@as(u64, 1), hash_map.min_hole);
    try std.testing.expect(hash_map.get(1) == null);

    try hash_map.add(1, 5);
    try std.testing.expectEqual(@as(u64, 2), hash_map.min_hole);
    try std.testing.expectEqual(@as(u64, 5), hash_map.get(1).?);

    try hash_map.add(3, 3);
    try std.testing.expectEqual(@as(u64, 2), hash_map.min_hole);
    try std.testing.expectEqual(@as(u64, 3), hash_map.get(3).?);

    try hash_map.add(2, 2);
    try std.testing.expectEqual(@as(u64, 4), hash_map.min_hole);
    try std.testing.expectEqual(@as(u64, 2), hash_map.get(2).?);
    try std.testing.expect(hash_map.get(4) == null);
}

test "MinHoleHashMap - sequential filling" {
    var hash_map = MinHoleHashMap.init(std.heap.page_allocator);
    defer hash_map.deinit();

    for (1..5) |i| {
        try std.testing.expectEqual(@as(u64, i), hash_map.min_hole);
        try hash_map.add(@as(u64, i), @as(u64, i));
    }
    try std.testing.expectEqual(@as(u64, 5), hash_map.min_hole);
}

test "MinHoleHashMap - filling holes" {
    var hash_map = MinHoleHashMap.init(std.heap.page_allocator);
    defer hash_map.deinit();

    try hash_map.add(2, 2);
    try std.testing.expectEqual(@as(u64, 1), hash_map.min_hole);

    try hash_map.add(1, 1);
    try std.testing.expectEqual(@as(u64, 3), hash_map.min_hole);

    try hash_map.add(3, 3);
    try std.testing.expectEqual(@as(u64, 4), hash_map.min_hole);
}

test "MinHoleHashMap - value updates" {
    var hash_map = MinHoleHashMap.init(std.heap.page_allocator);
    defer hash_map.deinit();

    // Add initial values
    try hash_map.add(1, 5);
    try hash_map.add(2, 3);
    try hash_map.add(3, 4);

    // Update value for key 2 to be smaller
    try hash_map.add(2, 2);
    const result = hash_map.findMinValue();
    try std.testing.expectEqual(@as(u64, 2), result.present.value);
    try std.testing.expectEqual(@as(u64, 2), result.present.index);

    // Update value for key 1 to be even smaller
    try hash_map.add(1, 1);
    const new_result = hash_map.findMinValue();
    try std.testing.expectEqual(@as(u64, 1), new_result.present.value);
    try std.testing.expectEqual(@as(u64, 1), new_result.present.index);
}

test "findMinValue - empty hash map" {
    var hash_map = MinHoleHashMap.init(std.heap.page_allocator);
    defer hash_map.deinit();

    const result = hash_map.findMinValue();
    try std.testing.expectEqual(@as(u64, 1), result.missing);
}

test "findMinValue - full hash map" {
    var hash_map = MinHoleHashMap.init(std.heap.page_allocator);
    defer hash_map.deinit();

    for (1..5) |i| {
        try hash_map.add(i, i);
    }

    const result = hash_map.findMinValue();
    try std.testing.expectEqual(@as(u64, 1), result.present.index);
    try std.testing.expectEqual(@as(u64, 1), result.present.value);
}

test "findMinValue - partial hash map with missing smaller" {
    var hash_map = MinHoleHashMap.init(std.heap.page_allocator);
    defer hash_map.deinit();

    // Add 2, 3, 5 to hash map
    try hash_map.add(2, 2);
    try hash_map.add(3, 3);
    try hash_map.add(5, 5);

    const result = hash_map.findMinValue();
    try std.testing.expectEqual(@as(u64, 1), result.missing);
}

test "findMinValue - partial hash map with present smaller" {
    var hash_map = MinHoleHashMap.init(std.heap.page_allocator);
    defer hash_map.deinit();

    // Add 1, 3, 5 to hash map
    try hash_map.add(1, 1);
    try hash_map.add(3, 3);
    try hash_map.add(5, 5);

    const result = hash_map.findMinValue();
    try std.testing.expectEqual(@as(u64, 1), result.present.value);
    try std.testing.expectEqual(@as(u64, 1), result.present.index);
}

test "doubleMinValue - missing value" {
    var hash_map = MinHoleHashMap.init(std.heap.page_allocator);
    defer hash_map.deinit();

    try hash_map.doubleMinValue();
    try std.testing.expectEqual(@as(u64, 2), hash_map.get(1).?);
}

test "doubleMinValue - present value" {
    var hash_map = MinHoleHashMap.init(std.heap.page_allocator);
    defer hash_map.deinit();

    try hash_map.add(1, 1);
    try hash_map.doubleMinValue();
    try std.testing.expectEqual(@as(u64, 2), hash_map.get(1).?);
} 