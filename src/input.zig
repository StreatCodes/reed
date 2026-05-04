const std = @import("std");
const wayland = @import("wayland");
const river = wayland.client.river;
const wl = wayland.client.wl;
const Instance = @import("Instance.zig");
const actions = @import("actions.zig");

pub fn seatListener(_: *river.SeatV1, event: river.SeatV1.Event, instance: *Instance) void {
    _ = instance;
    switch (event) {
        .window_interaction => |interaction| {
            _ = interaction;
            std.debug.print("Window interaction\n", .{});
        },

        else => {},
    }
}

const KeyBindings = struct {
    keysym: u32,
    action: actions.Action,
};

// Temporary hard coded bindings
const bindings = [_]KeyBindings{
    .{
        .action = .open,
        .keysym = 0x0020, //Space
    },
    .{
        .action = .close,
        .keysym = 0x0030, //0
    },
};

const BindingMap = struct {
    instance: *Instance,
    action: actions.Action,
};

pub fn initKeyBindings(instance: *Instance) !void {
    const xkb_bindings = instance.xkb_bindings orelse {
        std.debug.print("Failed to find xkb bindings\n", .{});
        return;
    };

    for (bindings) |binding| {
        std.debug.print("Registering binding {x} {any}\n", .{ binding.keysym, binding.action });
        const xkb_binding = xkb_bindings.getXkbBinding(
            instance.seat.?,
            binding.keysym,
            .{},
        ) catch |err| {
            std.debug.print("Failed to register binding ({}): {}\n", .{ binding, err });
            return;
        };

        try instance.actionMap.put(xkb_binding.getId(), binding.action);

        xkb_binding.setListener(*Instance, xkbBindingListener, instance);
        xkb_binding.enable();
    }
}

fn xkbBindingListener(
    xkb_binding: *river.XkbBindingV1,
    event: river.XkbBindingV1.Event,
    instance: *Instance,
) void {
    switch (event) {
        .pressed => {
            std.debug.print("Key pressed {x}\n", .{xkb_binding.getId()});
            const action = instance.actionMap.get(xkb_binding.getId()) orelse {
                std.debug.print("Unknown binding {d}\n", .{xkb_binding.getId()});
                return;
            };

            actions.execAction(instance, action);
        },
        else => {},
    }
}
