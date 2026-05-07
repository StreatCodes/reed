const std = @import("std");
const wayland = @import("wayland");
const Instance = @import("Instance.zig");
const river = wayland.client.river;
const wl = wayland.client.wl;

pub fn handleManageStart(instance: *Instance, window_manager: *river.WindowManagerV1) !void {
    std.debug.print("Manage start\n", .{});

    for (instance.windows.items) |window| {
        if (window.new) {
            window.river_window.proposeDimensions(600, 600);
            window.river_node.setPosition(window.x, window.y);
            instance.seat.?.focusWindow(window.river_window);
        }
    }
    window_manager.manageFinish();
}
