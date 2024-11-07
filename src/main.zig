const std = @import("std");
const debug = std.debug.print;
const exit = std.process.exit;

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
        debug("No directory name given\n", .{});
        exit(1);
    }
}

pub fn count(dir_name: []const u8) !void {
    // open the directory as an iterator
    var dir = std.fs.cwd().openDir(dir_name, .{ .iterate = true }) catch |e| {
        debug("Error accessing directory \"{s}\": {any}\n", .{ dir_name, e });
        exit(1);
    };
    defer dir.close();

    var file_count: usize = 0;
    var dir_count: usize = 0;
    var total_count: usize = 0;

    var iter = dir.iterate();
    while (try iter.next()) |item| {
        if (item.kind == .file) {
            file_count += 1;
        } else {
            dir_count += 1;
        }
        total_count += 1;
    }

    debug("Files: {d}\n", .{file_count});
    debug("Directories: {d}\n", .{dir_count});
    debug("Total: {d}\n", .{total_count});
}
