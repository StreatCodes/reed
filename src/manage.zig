const std = @import("std");
const wayland = @import("wayland");
const Instance = @import("Instance.zig");
const river = wayland.client.river;

pub fn handleManageStart(window_manager: *river.WindowManagerV1) !void {
    std.debug.print("Manage start\n", .{});
    const instance = Instance.get();

    var focus_window_idx: ?usize = null;

    for (instance.windows.items, 0..) |*window, index| {
        if (window.new) {
            window.river_window.proposeDimensions(600, 600);
            window.river_node.setPosition(window.x, window.y);
            focus_window_idx = index;
            window.new = false;
        }

        if (window.interacted) {
            focus_window_idx = index;
            window.interacted = false;
        }

        const seat = instance.seat orelse continue;
        if (seat.op_action) |action| {
            switch (action) {
                .move => {
                    const new_x = seat.op_start_x + seat.op_dx;
                    const new_y = seat.op_start_y + seat.op_dy;
                    window.setPosition(new_x, new_y);
                },
            }

            if (seat.op_released) {
                seat.river_seat.opEnd();
                seat.op_action = null;
                seat.op_released = false;
            }
        }
    }

    if (focus_window_idx) |index| {
        focusWindow(instance, index);
    }

    window_manager.manageFinish();
}

/// Inform river of the new window focus and place it on top. We also
/// move it to the last position in the instance window array, as that's
/// how we track the focused window on our side.
fn focusWindow(instance: *Instance, index: usize) void {
    const window = instance.windows.orderedRemove(index);
    instance.windows.append(instance.allocator, window) catch @panic("Failed to focus window");

    window.river_node.placeTop();
    instance.seat.?.river_seat.focusWindow(window.river_window);
}
