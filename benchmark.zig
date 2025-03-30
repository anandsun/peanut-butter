const std = @import("std");
const seq = @import("redistribute_two_factors_sequences.zig");
const arr = @import("redistribute_two_factors_array.zig");

pub fn main() void {
    const sizes = [_]u64{ 1000, 5000, 10000 };
    const num_runs = 5;
    
    for (sizes) |n| {
        std.debug.print("\nBenchmarking with N={d}, {d} runs each\n", .{n, num_runs});
        std.debug.print("=====================================\n", .{});
        
        // Benchmark sequence-based implementation
        var seq_times: [5]i64 = undefined;
        for (0..num_runs) |i| {
            const start_time = std.time.milliTimestamp();
            if (seq.redistributeTwoFactors(n)) |result| {
                const end_time = std.time.milliTimestamp();
                seq_times[i] = end_time - start_time;
                std.debug.print("Sequence-based run {d}: {d}ms\n", .{i + 1, seq_times[i]});
                std.heap.page_allocator.free(result);
            } else |err| {
                std.debug.print("Error in sequence-based run {d}: {any}\n", .{i + 1, err});
                seq_times[i] = -1;
            }
        }
        
        // Benchmark array-based implementation
        var arr_times: [5]i64 = undefined;
        for (0..num_runs) |i| {
            const start_time = std.time.milliTimestamp();
            if (arr.redistributeTwoFactors(n)) |result| {
                const end_time = std.time.milliTimestamp();
                arr_times[i] = end_time - start_time;
                std.debug.print("Array-based run {d}: {d}ms\n", .{i + 1, arr_times[i]});
                std.heap.page_allocator.free(result);
            } else |err| {
                std.debug.print("Error in array-based run {d}: {any}\n", .{i + 1, err});
                arr_times[i] = -1;
            }
        }
        
        // Calculate and print statistics
        var seq_sum: i64 = 0;
        var arr_sum: i64 = 0;
        var seq_count: usize = 0;
        var arr_count: usize = 0;
        
        for (seq_times) |time| {
            if (time >= 0) {
                seq_sum += time;
                seq_count += 1;
            }
        }
        
        for (arr_times) |time| {
            if (time >= 0) {
                arr_sum += time;
                arr_count += 1;
            }
        }
        
        if (seq_count > 0) {
            const seq_avg = @as(f64, @floatFromInt(seq_sum)) / @as(f64, @floatFromInt(seq_count));
            std.debug.print("\nSequence-based average: {d:.2}ms\n", .{seq_avg});
        }
        
        if (arr_count > 0) {
            const arr_avg = @as(f64, @floatFromInt(arr_sum)) / @as(f64, @floatFromInt(arr_count));
            std.debug.print("Array-based average: {d:.2}ms\n", .{arr_avg});
        }
        
        std.debug.print("=====================================\n", .{});
    }
} 