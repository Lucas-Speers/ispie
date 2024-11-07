const std = @import("std");
const mem = std.mem;
const debug = std.debug.print;
const exit = std.process.exit;

const Dir = std.fs.Dir;

const allocator = std.heap.page_allocator;

pub fn main() !void {
    // get the second argument as the directory name
    var args = try std.process.argsWithAllocator(allocator);
    defer args.deinit();

    // the first argument is the program name ("ispie")
    _ = args.next();

    if (args.next()) |dir_name| {
        try count(dir_name);
    } else {
        debug("Usage: ispie DIRECTORY_NAME [OPTIONS]\n", .{});
        exit(1);
    }
}

pub fn openDir(dir_name: []const u8) !Dir {
    // open the directory as an iterator
    return std.fs.cwd().openDir(dir_name, .{ .iterate = true });
}

const Stats = struct {
    file_count: usize = 0,
    dir_count: usize = 0,
    total_count: usize = 0,
    total_file_sizes: usize = 0,
    atimes: std.ArrayList(i128),
};

pub fn count(dir_name: []const u8) !void {
    var stats: Stats = .{
        .atimes = std.ArrayList(i128).init(allocator),
    };

    try countAllInDir(dir_name, &stats);

    var min_atime: ?i128 = null;
    var max_atime: ?i128 = null;

    for (stats.atimes.items) |item| {
        if (min_atime == null) min_atime = item;
        if (max_atime == null) max_atime = item;

        if (min_atime orelse unreachable > item) min_atime = item;
        if (max_atime orelse unreachable < item) max_atime = item;
    }

    debug("Files: {d}\n", .{stats.file_count});
    debug("Directories: {d}\n", .{stats.dir_count});
    debug("Total: {d}\n", .{stats.total_count});
    debug("Total Size: {d}\n", .{stats.total_file_sizes});
    debug("atimes: {any}\n", .{stats.atimes.items});
    debug("atimes min: {d}\n", .{min_atime orelse unreachable});
    debug("atimes max: {d}\n", .{max_atime orelse unreachable});
    debug("atimes diff: {d}\n", .{(max_atime orelse unreachable) - (min_atime orelse unreachable)});
}

pub fn countAllInDir(dir_name: []const u8, stats: *Stats) !void {
    var dir = try openDir(dir_name);
    defer dir.close();

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

            stats.atimes.append(@divFloor(stat.atime, @as(i128, std.time.ns_per_s))) catch unreachable;
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
