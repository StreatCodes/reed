const std = @import("std");
const wayland = @import("wayland");
const river = wayland.client.river;
const wl = wayland.client.wl;
const Instance = @import("Instance.zig");
const actions = @import("actions.zig");
const events = @import("events.zig");

const InputError = error{
    MultiSeatUnsupported,
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

    //TODO apply other mouse bindings here
    setPointerBinding(instance, .left, .{ .mod4 = true }, .mouse_test);
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
    keysym: events.Key,
    action: actions.Action,
    modifiers: river.SeatV1.Modifiers,
};

// Temporary hard coded bindings
const bindings = [_]KeyBinding{
    .{
        .action = .open,
        .keysym = .space,
        .modifiers = .{ .mod4 = true },
    },
    .{
        .action = .close,
        .keysym = .q,
        .modifiers = .{ .mod4 = true },
    },
};

const BindingMap = struct {
    instance: *Instance,
    action: actions.Action,
};

fn initKeyBindings(instance: *Instance) !void {
    const xkb_bindings = instance.xkb_bindings orelse {
        std.debug.print("Failed to find xkb bindings\n", .{});
        return;
    };

    for (bindings) |binding| {
        std.debug.print("Registering key binding {x} {any}\n", .{ binding.keysym, binding.action });
        const xkb_binding = xkb_bindings.getXkbBinding(
            instance.seat.?,
            @intFromEnum(binding.keysym),
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
    const action = instance.actionMap.get(xkb_binding.getId()) orelse {
        std.debug.print("Unknown binding {d}\n", .{xkb_binding.getId()});
        return;
    };

    switch (event) {
        .pressed => actions.execAction(instance, action, .pressed),
        .released => actions.execAction(instance, action, .released),
        .stop_repeat => actions.execAction(instance, action, .stop_repeat),
    }
}

//TODO keep track of the bindings and release them on shutdown
fn setPointerBinding(instance: *Instance, button: events.Mouse, modifiers: river.SeatV1.Modifiers, action: actions.Action) void {
    const binding = instance.seat.?.getPointerBinding(@intFromEnum(button), modifiers) catch {
        std.debug.print("Failed to setup pointer binding\n", .{});
        return;
    };

    instance.actionMap.put(binding.getId(), action) catch {
        std.debug.print("Failed to store pointer binding\n", .{});
        return;
    };

    std.debug.print("Registering pointer binding {any}\n", .{action});
    binding.setListener(*Instance, pointerBindingListener, instance);
    binding.enable();
}

fn pointerBindingListener(
    pointer_binding: *river.PointerBindingV1,
    event: river.PointerBindingV1.Event,
    instance: *Instance,
) void {
    const action = instance.actionMap.get(pointer_binding.getId()) orelse {
        std.debug.print("Unknown pointer binding {d}\n", .{pointer_binding.getId()});
        return;
    };

    switch (event) {
        .pressed => actions.execAction(instance, action, .pressed),
        .released => actions.execAction(instance, action, .released),
    }
}
