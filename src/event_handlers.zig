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

pub fn handleExit(_: *river.XkbBindingV1, event: river.XkbBindingV1.Event, instance: *Instance) void {
    if (event == .pressed) {
        std.debug.print("Exiting\n", .{});
        instance.exit = true;
    }
}

pub fn handlePassthrough(passthrough_binding: *river.XkbBindingV1, event: river.XkbBindingV1.Event, instance: *Instance) void {
    if (event != .pressed) return;
    const seat = instance.seat orelse return;

    seat.passthrough = !seat.passthrough;
    std.debug.print("Enabling binding id {d}\n", .{passthrough_binding.getId()});

    for (seat.bindings.items) |binding| {
        switch (binding) {
            .key => |key_binding| {
                if (key_binding.getId() == passthrough_binding.getId()) continue;
                if (seat.passthrough) {
                    std.debug.print("Disabling key binding {d}\n", .{key_binding.getId()});
                    key_binding.disable();
                } else {
                    std.debug.print("Enabling key binding {d}\n", .{key_binding.getId()});
                    key_binding.enable();
                }
            },
            .pointer => |pointer_binding| {
                if (seat.passthrough) {
                    std.debug.print("Disabling pointer binding {d}\n", .{pointer_binding.getId()});
                    pointer_binding.disable();
                } else {
                    std.debug.print("Enabling pointer binding {d}\n", .{pointer_binding.getId()});
                    pointer_binding.enable();
                }
            },
        }
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
