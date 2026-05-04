const std = @import("std");
const wayland = @import("wayland");
const river = wayland.client.river;
const Reed = @import("Reed.zig");

pub fn handleKeyPressed(reed: *Reed) void {
    std.debug.print("Exiting\n", .{});
    reed.exit = true;
}
