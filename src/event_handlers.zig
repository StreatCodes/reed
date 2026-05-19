const std = @import("std");
const wayland = @import("wayland");
const river = wayland.client.river;
const Instance = @import("Instance.zig");
const window = @import("window.zig");

pub const KeyListener = *const fn (xkb_binding_v1: *river.XkbBindingV1, event: river.XkbBindingV1.Event, data: *Instance) void;
pub const PointerListener = *const fn (pointer_binding_v1: *river.PointerBindingV1, event: river.PointerBindingV1.Event, data: *Instance) void;

pub fn handleOpenLauncher(_: *river.XkbBindingV1, event: river.XkbBindingV1.Event, instance: *Instance) void {
    if (event == .pressed) {
        const command = &[_][]const u8{"wmenu-run"};
        _ = std.process.spawn(instance.io, .{
            .argv = command,
            .pgid = 0,
        }) catch |err| {
            std.debug.print("Failed to open program {}\n", .{err});
        };
    }
}

pub fn handleWindowClose(_: *river.XkbBindingV1, event: river.XkbBindingV1.Event, instance: *Instance) void {
    if (event == .pressed) {
        if (instance.windows.items.len == 0) return;
        const w = instance.windows.getLast();
        w.river_window.close();
    }
}

pub fn handleMoveWindow(_: *river.PointerBindingV1, event: river.PointerBindingV1.Event, instance: *Instance) void {
    const seat = instance.seat orelse return;
    const window_id = seat.hover_id orelse return;
    const result = window.getWindow(instance.windows.items, window_id) orelse {
        std.debug.print("Couldn't find hovered window for move operation {}, ignoring\n", .{window_id});
        return;
    };

    if (event == .pressed) {
        seat.startPointerOperation(result.window, .move, null);
    }
}

pub fn handleResizeWindow(_: *river.PointerBindingV1, event: river.PointerBindingV1.Event, instance: *Instance) void {
    const seat = instance.seat orelse return;
    const window_id = seat.hover_id orelse return;
    const result = window.getWindow(instance.windows.items, window_id) orelse {
        std.debug.print("Couldn't find hovered window for move operation {}, ignoring\n", .{window_id});
        return;
    };

    if (event == .pressed) {
        seat.startPointerOperation(result.window, .resize, .{ .bottom = true, .right = true });
    }
}
