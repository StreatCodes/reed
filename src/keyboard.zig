const std = @import("std");
const wayland = @import("wayland");
const river = wayland.client.river;
const Instance = @import("Instance.zig");

pub fn handleKeyPressed(instance: *Instance) void {
    std.debug.print("Exiting\n", .{});
    instance.exit = true;
}
