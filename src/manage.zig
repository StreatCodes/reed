const std = @import("std");
const wayland = @import("wayland");
const Instance = @import("Instance.zig");
const river = wayland.client.river;

/// The handler for River's Manage sequence. Any changes to window position,
/// focus, size or z-index should happen here.
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
        if (seat.operation) |*operation| {
            switch (operation.action) {
                .move => {
                    const new_x = operation.window_start_x + operation.dx;
                    const new_y = operation.window_start_y + operation.dy;
                    window.setPosition(new_x, new_y);
                },
                .resize => {
                    var new_x = operation.window_start_x;
                    var new_y = operation.window_start_y;
                    var new_w = operation.window_start_w;
                    var new_h = operation.window_start_h;

                    if (operation.edges.left) {
                        new_w -= operation.dx;
                        new_x += operation.dx;
                    }
                    if (operation.edges.top) {
                        new_h -= operation.dy;
                        new_y += operation.dy;
                    }
                    if (operation.edges.right) {
                        new_w += operation.dx;
                    }
                    if (operation.edges.bottom) {
                        new_h += operation.dy;
                    }

                    // Prevent resizing below a minimun
                    if (new_w < 120) new_w = 120;
                    if (new_h < 120) new_h = 120;

                    window.setPosition(new_x, new_y);
                    window.setSize(new_w, new_h);
                },
            }

            if (operation.released) {
                seat.river_seat.opEnd();
                seat.operation = null;
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
