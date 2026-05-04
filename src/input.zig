const std = @import("std");
const wayland = @import("wayland");
const river = wayland.client.river;
const wl = wayland.client.wl;
const Instance = @import("Instance.zig");

pub fn seatListener(
    _: *river.SeatV1,
    event: river.SeatV1.Event,
    instance: *Instance,
) void {
    _ = instance;
    switch (event) {
        .window_interaction => |interaction| {
            _ = interaction;
            std.debug.print("Window interaction\n", .{});
        },

        else => {},
    }
}

pub fn initKeyBindings(instance: *Instance) !void {
    const xkb_bindings = instance.xkb_bindings orelse {
        std.debug.print("Failed to find xkb bindings\n", .{});
        return;
    };

    // TODO This is dumb, redo
    var keys: std.ArrayList(*river.XkbBindingV1) = .empty;

    // 0x0020 Spacebar
    const xkb_binding = xkb_bindings.getXkbBinding(
        instance.seat.?,
        0x0020,
        .{},
    ) catch |err| {
        std.debug.print("Failed to get xkb binding: {}\n", .{err});
        return;
    };

    try keys.append(instance.allocator, xkb_binding);
    instance.key_bindings = try keys.toOwnedSlice(instance.allocator);

    xkb_binding.setListener(*Instance, xkbBindingListener, instance);
    xkb_binding.enable();
}

fn xkbBindingListener(
    xkb_binding: *river.XkbBindingV1,
    event: river.XkbBindingV1.Event,
    instance: *Instance,
) void {
    switch (event) {
        .pressed => {
            std.debug.print("Key pressed {d}\n", .{xkb_binding.getId()});
            handleKeyPressed(instance);
        },
        else => {},
    }
}

pub fn handleKeyPressed(instance: *Instance) void {
    std.debug.print("Exiting\n", .{});
    instance.exit = true;
}
