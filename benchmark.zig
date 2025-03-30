const std = @import("std");
const seq = @import("redistribute_two_factors_sequences.zig");
const arr = @import("redistribute_two_factors_array.zig");

pub fn main() void {
    const sizes = [_]u64{ 50, 100, 500, 1000, 10000, 25000, 50000, 75000, 100000 };
    const num_runs = 5;
    const timeout_ns = 2 * std.time.ns_per_s; // 2 seconds in nanoseconds
    const skip_threshold_ns = 1 * std.time.ns_per_s; // 1 second threshold for skipping larger sizes
    
    // Benchmark sequence-based implementation
    std.debug.print("\nBenchmarking sequence-based implementation:\n", .{});
    std.debug.print("=====================================\n", .{});
    var should_continue = true;
    
    for (sizes) |n| {
        if (!should_continue) break;
        
        std.debug.print("\nN={d}, {d} runs\n", .{n, num_runs});
        var seq_times: [5]i64 = undefined;
        var max_time_ns: u64 = 0;
        var timeout_count: usize = 0;
        
        for (0..num_runs) |i| {
            if (timeout_count >= 2) {
                std.debug.print("Stopping after {d} timeouts\n", .{timeout_count});
                break;
            }
            
            var timer = std.time.Timer.start() catch continue;
            if (seq.redistributeTwoFactors(n)) |result| {
                const elapsed_ns = timer.lap();
                if (elapsed_ns > timeout_ns) {
                    std.debug.print("Run {d}: TIMEOUT (>2s)\n", .{i + 1});
                    seq_times[i] = -1;
                    timeout_count += 1;
                    should_continue = false;
                } else {
                    const elapsed_ms = @divTrunc(elapsed_ns, std.time.ns_per_ms);
                    seq_times[i] = @intCast(elapsed_ms);
                    std.debug.print("Run {d}: {d}ms\n", .{i + 1, elapsed_ms});
                    if (elapsed_ns > max_time_ns) {
                        max_time_ns = elapsed_ns;
                    }
                }
                std.heap.page_allocator.free(result);
            } else |err| {
                std.debug.print("Error in run {d}: {any}\n", .{i + 1, err});
                seq_times[i] = -1;
                should_continue = false;
            }
        }
        
        // Calculate and print statistics
        var sum: i64 = 0;
        var count: usize = 0;
        
        for (seq_times) |time| {
            if (time >= 0) {
                sum += time;
                count += 1;
            }
        }
        
        if (count > 0) {
            const avg = @as(f64, @floatFromInt(sum)) / @as(f64, @floatFromInt(count));
            std.debug.print("\nAverage: {d:.2}ms\n", .{avg});
        }
        
        // Check if we should continue to larger sizes
        if (max_time_ns > skip_threshold_ns) {
            std.debug.print("\nSkipping larger sizes (current size took >{d}ms)\n", .{@divTrunc(skip_threshold_ns, std.time.ns_per_ms)});
            should_continue = false;
        }
        
        std.debug.print("-------------------------------------\n", .{});
    }
    
    // Benchmark array-based implementation
    std.debug.print("\nBenchmarking array-based implementation:\n", .{});
    std.debug.print("=====================================\n", .{});
    should_continue = true;
    
    for (sizes) |n| {
        if (!should_continue) break;
        
        std.debug.print("\nN={d}, {d} runs\n", .{n, num_runs});
        var arr_times: [5]i64 = undefined;
        var max_time_ns: u64 = 0;
        var timeout_count: usize = 0;
        
        for (0..num_runs) |i| {
            if (timeout_count >= 2) {
                std.debug.print("Stopping after {d} timeouts\n", .{timeout_count});
                break;
            }
            
            var timer = std.time.Timer.start() catch continue;
            if (arr.redistributeTwoFactors(n)) |result| {
                const elapsed_ns = timer.lap();
                if (elapsed_ns > timeout_ns) {
                    std.debug.print("Run {d}: TIMEOUT (>2s)\n", .{i + 1});
                    arr_times[i] = -1;
                    timeout_count += 1;
                    should_continue = false;
                } else {
                    const elapsed_ms = @divTrunc(elapsed_ns, std.time.ns_per_ms);
                    arr_times[i] = @intCast(elapsed_ms);
                    std.debug.print("Run {d}: {d}ms\n", .{i + 1, elapsed_ms});
                    if (elapsed_ns > max_time_ns) {
                        max_time_ns = elapsed_ns;
                    }
                }
                std.heap.page_allocator.free(result);
            } else |err| {
                std.debug.print("Error in run {d}: {any}\n", .{i + 1, err});
                arr_times[i] = -1;
                should_continue = false;
            }
        }
        
        // Calculate and print statistics
        var sum: i64 = 0;
        var count: usize = 0;
        
        for (arr_times) |time| {
            if (time >= 0) {
                sum += time;
                count += 1;
            }
        }
        
        if (count > 0) {
            const avg = @as(f64, @floatFromInt(sum)) / @as(f64, @floatFromInt(count));
            std.debug.print("\nAverage: {d:.2}ms\n", .{avg});
        }
        
        // Check if we should continue to larger sizes
        if (max_time_ns > skip_threshold_ns) {
            std.debug.print("\nSkipping larger sizes (current size took >{d}ms)\n", .{@divTrunc(skip_threshold_ns, std.time.ns_per_ms)});
            should_continue = false;
        }
        
        std.debug.print("-------------------------------------\n", .{});
    }
} 