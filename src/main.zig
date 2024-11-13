const std = @import("std");
const mem = std.mem;
const debug = std.debug.print;
const exit = std.process.exit;
const Dir = std.fs.Dir;

const graphs = @import("graphs.zig");
const time = @import("time.zig");

const allocator = std.heap.page_allocator;

pub fn main() !void {
    // get the second argument as the directory name
    var args = try std.process.argsWithAllocator(allocator);
    defer args.deinit();

    // the first argument is the program name
    _ = args.next();

    try count(args.next() orelse ".");
}

pub fn openDir(dir_name: []const u8) !Dir {
    // open the directory as an iterator
    return std.fs.cwd().openDir(dir_name, .{ .iterate = true });
}

pub const Stats = struct {
    file_count: usize = 0,
    dir_count: usize = 0,
    total_count: usize = 0,
    total_file_sizes: usize = 0,
    atimes: std.ArrayList(i128),
};

pub fn count(dir_name: []const u8) !void {
    debug("Scanning \"{s}\"\n", .{try std.fs.cwd().realpathAlloc(allocator, dir_name)});

    var stats: Stats = .{
        .atimes = std.ArrayList(i128).init(allocator),
    };

    try countAllInDir(dir_name, &stats);
    debug("\n", .{});

    var min_atime: ?i128 = null;
    var max_atime: ?i128 = null;

    for (stats.atimes.items) |item| {
        if (min_atime == null) min_atime = item;
        if (max_atime == null) max_atime = item;

        if (min_atime orelse unreachable > item) min_atime = item;
        if (max_atime orelse unreachable < item) max_atime = item;
    }

    // graphs.make_graph(stats.atimes, 7, 5);

    debug("Files:           {d}\n", .{stats.file_count});
    debug("Directories:     {d}\n", .{stats.dir_count});
    debug("Total:           {d}\n", .{stats.total_count});
    debug("Total Size:      ", .{});
    printSize(stats.total_file_sizes);
    debug("\n", .{});
    debug("Oldest accesed:  {s}\n", .{time.toReadable(time.fromTimestamp(@intCast(min_atime orelse unreachable)))});
    debug("Newest accesed:  {s}\n", .{time.toReadable(time.fromTimestamp(@intCast(max_atime orelse unreachable)))});
}

pub fn countAllInDir(dir_name: []const u8, stats: *Stats) !void {
    var dir = try openDir(dir_name);
    defer dir.close();

    debug("{s}\x1b[K\r", .{try std.fs.cwd().realpathAlloc(allocator, dir_name)});

    var iter = dir.iterate();
    while (try iter.next()) |item| {
        // get the full path
        const full_path = pathConcat(dir_name, item.name, allocator);
        defer allocator.free(full_path);

        if (item.kind == .file) {
            stats.file_count += 1;

            const file = std.fs.cwd().openFile(full_path, .{}) catch unreachable;
            const stat = file.stat() catch unreachable;

            stats.total_file_sizes += stat.size;

            const atime_seconds = @divFloor(stat.atime, @as(i128, std.time.ns_per_s));

            stats.atimes.append(atime_seconds) catch unreachable;
        } else if (item.kind == .directory) {
            stats.dir_count += 1;

            countAllInDir(full_path, stats) catch continue;
        }
        stats.total_count += 1;
    }
}

// some string concatination
// "directory" and "file" should be "directory/file"
pub fn pathConcat(s1: []const u8, s2: []const u8, alloc: mem.Allocator) []u8 {
    const dir_with_slash = stringConcat(s1, "/", alloc);
    defer allocator.free(dir_with_slash);
    const full_path = stringConcat(dir_with_slash, s2, alloc);
    return full_path;
}

pub fn stringConcat(s1: []const u8, s2: []const u8, alloc: mem.Allocator) []u8 {
    var result = alloc.alloc(u8, s1.len + s2.len) catch unreachable;
    @memcpy(result[0..s1.len], s1);
    @memcpy(result[s1.len..], s2);
    return result;
}

pub fn printSize(size: usize) void {
    if (size > 1_000_000_000) {
        debug("{} GB", .{size / 1_000_000_000});
    } else if (size > 1_000_000) {
        debug("{} MB", .{size / 1_000_000});
    } else if (size > 1_000) {
        debug("{} KB", .{size / 1_000});
    } else {
        debug("{} B", .{size});
    }
}
