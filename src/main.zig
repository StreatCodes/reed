const std = @import("std");
const Instance = @import("Instance.zig");

pub fn main(init: std.process.Init) !void {
    const gpa = init.gpa;

    std.debug.print("Initialising Reed\n", .{});
    var instance = try Instance.init(gpa);
    defer instance.deinit();

    instance.run();

    std.debug.print("Shutting down\n", .{});
}
