const std = @import("std");
const debug = std.debug.print;

pub fn make_graph(array: std.ArrayList(i128), width: usize, hight: usize) void {
    _ = array;
    for (0..hight) |h| {
        for (0..width) |_| {
            debug("_", .{});
        }
        debug("| {}\n", .{hight - h});
    }

    debug("", .{});
}
