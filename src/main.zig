const std = @import("std");
const Reed = @import("Reed.zig");

pub fn main(init: std.process.Init) !void {
    const gpa = init.gpa;

    std.debug.print("Initialising Reed\n", .{});
    var reed = try Reed.init(gpa);
    defer reed.deinit();

    try reed.register();
    reed.run();

    std.debug.print("Shutting down\n", .{});
}
