const std = @import("std");
const Instance = @import("Instance.zig");

pub fn main(init: std.process.Init) !void {
    std.debug.print("Initialising Reed\n", .{});
    var instance = try Instance.init(init.io, init.gpa);
    defer instance.deinit();

    instance.run();

    std.debug.print("Shutting down\n", .{});
}
