const std = @import("std");

pub const MinHoleHashMap = struct {
    hash_map: std.AutoHashMap(u64, void),
    min_hole: u64,

    pub fn init(allocator: std.mem.Allocator) MinHoleHashMap {
        return .{
            .hash_map = std.AutoHashMap(u64, void).init(allocator),
            .min_hole = 1,
        };
    }

    pub fn deinit(self: *MinHoleHashMap) void {
        self.hash_map.deinit();
    }

    pub fn add(self: *MinHoleHashMap, key: u64) !void {
        try self.hash_map.put(key, {});
        if (key == self.min_hole) {
            // If we just filled the current minimum hole, find the next one
            while (self.hash_map.contains(self.min_hole)) {
                self.min_hole += 1;
            }
        }
    }

    pub fn get(self: *const MinHoleHashMap, key: u64) bool {
        return self.hash_map.contains(key);
    }
};

test "MinHoleHashMap - basic operations" {
    var hash_map = MinHoleHashMap.init(std.heap.page_allocator);
    defer hash_map.deinit();

    try std.testing.expectEqual(@as(u64, 1), hash_map.min_hole);
    try std.testing.expect(!hash_map.get(1));

    try hash_map.add(1);
    try std.testing.expectEqual(@as(u64, 2), hash_map.min_hole);
    try std.testing.expect(hash_map.get(1));

    try hash_map.add(3);
    try std.testing.expectEqual(@as(u64, 2), hash_map.min_hole);
    try std.testing.expect(hash_map.get(3));

    try hash_map.add(2);
    try std.testing.expectEqual(@as(u64, 4), hash_map.min_hole);
    try std.testing.expect(hash_map.get(2));
    try std.testing.expect(!hash_map.get(4));
}

test "MinHoleHashMap - sequential filling" {
    var hash_map = MinHoleHashMap.init(std.heap.page_allocator);
    defer hash_map.deinit();

    var i: u64 = 1;
    while (i <= 5) : (i += 1) {
        try std.testing.expectEqual(i, hash_map.min_hole);
        try hash_map.add(i);
    }
    try std.testing.expectEqual(@as(u64, 6), hash_map.min_hole);
}

test "MinHoleHashMap - filling holes" {
    var hash_map = MinHoleHashMap.init(std.heap.page_allocator);
    defer hash_map.deinit();

    try hash_map.add(2);
    try std.testing.expectEqual(@as(u64, 1), hash_map.min_hole);

    try hash_map.add(1);
    try std.testing.expectEqual(@as(u64, 3), hash_map.min_hole);

    try hash_map.add(3);
    try std.testing.expectEqual(@as(u64, 4), hash_map.min_hole);
} 