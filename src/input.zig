const std = @import("std");
const wayland = @import("wayland");
const river = wayland.client.river;
const wl = wayland.client.wl;
const Instance = @import("Instance.zig");
const actions = @import("actions.zig");

const InputError = error{
    MultiSeatUnsupported,
};

//TODO move me
const MouseButton = enum(u32) {
    left = 0x110, // BTN_LEFT
    right = 0x111, // BTN_RIGHT
    middle = 0x112, // BTN_MIDDLE
    side = 0x113, // BTN_SIDE
    extra = 0x114, // BTN_EXTRA
    forward = 0x115, // BTN_FORWARD
    back = 0x116, // BTN_BACK
};

pub fn handleNewSeat(instance: *Instance, seat: *river.SeatV1) InputError!void {
    std.debug.print("New seat {d}\n", .{seat.getId()});

    if (instance.seat != null) {
        return InputError.MultiSeatUnsupported;
    }

    instance.seat = seat;
    seat.setListener(*Instance, seatListener, instance);

    initKeyBindings(instance) catch |err| {
        std.debug.print("Failed to setup key bindings {}\n", .{err});
    };

    //TODO init mouse bindings
    const binding = seat.getPointerBinding(@intFromEnum(MouseButton.left), .{ .mod4 = true }) catch {
        std.debug.print("Failed to setup pointer bindings\n", .{});
        return;
    };
    _ = binding;
    //TODO move this to initPointerBindings
    //TODO use the binding, (don't forget to .enable it)
    //TODO will probably require a PointerBinding
}

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

const KeyBinding = struct {
    keysym: u32,
    action: actions.Action,
    modifiers: river.SeatV1.Modifiers,
};

// Temporary hard coded bindings
const bindings = [_]KeyBinding{
    .{
        .action = .open,
        .keysym = 0x0020, //Space
        .modifiers = .{ .mod4 = true },
    },
    .{
        .action = .close,
        .keysym = 0x0030, //0
        .modifiers = .{},
    },
    .{
        .action = .exit,
        .keysym = 0x0061, //a
        .modifiers = .{},
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
            binding.modifiers,
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
