const std = @import("std");
const seq = @import("redistribute_two_factors_sequences.zig");
const arr = @import("redistribute_two_factors_array.zig");
const hash = @import("redistribute_two_factors_hashmap.zig");

const Result = struct {
    name: []const u8,
    times: std.ArrayList([]i64),
};

fn benchmarkImplementation(
    comptime name: []const u8,
    comptime implementation: *const fn(u64) anyerror![]u64,
    sizes: []const u64,
    num_runs: u64,
    timeout_ns: u64,
    skip_threshold_ns: u64,
) !Result {
    var result = Result{
        .name = name,
        .times = std.ArrayList([]i64).init(std.heap.page_allocator),
    };
    errdefer result.times.deinit();

    var should_continue = true;
    
    for (sizes) |n| {
        if (!should_continue) break;
        
        var times = try std.heap.page_allocator.alloc(i64, num_runs);
        errdefer std.heap.page_allocator.free(times);
        var max_time_ns: u64 = 0;
        var timeout_count: usize = 0;
        
        for (0..num_runs) |i| {
            if (timeout_count >= 1) break;
            
            var timer = std.time.Timer.start() catch continue;
            if (implementation(n)) |impl_result| {
                const elapsed_ns = timer.lap();
                if (elapsed_ns > timeout_ns) {
                    times[i] = -1;
                    timeout_count += 1;
                    should_continue = false;
                } else {
                    const elapsed_ms = @divTrunc(elapsed_ns, std.time.ns_per_ms);
                    times[i] = @intCast(elapsed_ms);
                    if (elapsed_ns > max_time_ns) {
                        max_time_ns = elapsed_ns;
                    }
                }
                std.heap.page_allocator.free(impl_result);
            } else |_| {
                times[i] = -1;
                should_continue = false;
            }
        }
        
        try result.times.append(times);
        
        if (max_time_ns > skip_threshold_ns) {
            should_continue = false;
        }
    }
    
    return result;
}

fn calculateMean(times: []i64) ?f64 {
    var sum: i64 = 0;
    var count: usize = 0;
    
    for (times) |time| {
        if (time >= 0) {
            sum += time;
            count += 1;
        }
    }
    
    if (count > 0) {
        return @as(f64, @floatFromInt(sum)) / @as(f64, @floatFromInt(count));
    }
    return null;
}

pub fn main() !void {
    const sizes = [_]u64{ 50, 100, 500, 1000, 2500, 5000, 7500, 10000 };
    const num_runs = 5;
    const timeout_ns = 2 * std.time.ns_per_s; // 2 seconds in nanoseconds
    const skip_threshold_ns = 1 * std.time.ns_per_s; // 1 second threshold for skipping larger sizes
    
    var results = std.ArrayList(Result).init(std.heap.page_allocator);
    defer {
        for (results.items) |result| {
            for (result.times.items) |times| {
                std.heap.page_allocator.free(times);
            }
            result.times.deinit();
        }
        results.deinit();
    }
    
    try results.append(try benchmarkImplementation("sequence", seq.redistributeTwoFactors, &sizes, num_runs, timeout_ns, skip_threshold_ns));
    try results.append(try benchmarkImplementation("array", arr.redistributeTwoFactors, &sizes, num_runs, timeout_ns, skip_threshold_ns));
    try results.append(try benchmarkImplementation("hashmap", hash.redistributeTwoFactors, &sizes, num_runs, timeout_ns, skip_threshold_ns));
    
    // Create output file
    const file = try std.fs.cwd().createFile("benchmark_results.tsv", .{});
    defer file.close();
    
    // Create a buffered writer
    var buf_writer = std.io.bufferedWriter(file.writer());
    const writer = buf_writer.writer();
    
    // Write header
    try writer.print("Algorithm", .{});
    for (sizes) |n| {
        try writer.print("\tN={d}", .{n});
    }
    try writer.print("\n", .{});
    
    // Write data rows
    for (results.items) |result| {
        try writer.print("{s}", .{result.name});
        for (result.times.items) |times| {
            if (calculateMean(times)) |mean| {
                try writer.print("\t{d:.2}", .{mean});
            } else {
                try writer.print("\tTIMEOUT", .{});
            }
        }
        try writer.print("\n", .{});
    }
    
    // Flush the buffer to ensure all data is written
    try buf_writer.flush();
    
    std.debug.print("Benchmark results written to benchmark_results.tsv\n", .{});
}
