const std = @import("std");
const Reed = @import("Reed.zig");

pub fn main() !void {
    std.debug.print("Initialising Reed\n", .{});
    var reed = try Reed.init();
    defer reed.deinit();
}
