const std = @import("std");
const wayland = @import("wayland");
const river = wayland.client.river;
const wl = wayland.client.wl;
const Instance = @import("Instance.zig");
const actions = @import("actions.zig");
const events = @import("events.zig");
const screen = @import("screen.zig");

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

    // Hard coded for now
    setKeyBinding(instance, .space, .{ .mod4 = true }, .open);
    setKeyBinding(instance, .q, .{ .mod4 = true }, .close);

    //TODO apply other mouse bindings here
    setPointerBinding(instance, .left, .{ .mod4 = true }, .mouse_test);
}

pub fn seatListener(_: *river.SeatV1, event: river.SeatV1.Event, instance: *Instance) void {
    switch (event) {
        .window_interaction => |interaction| {
            const window_id = interaction.window.?.getId();
            const result = screen.getWindow(instance.windows.items, window_id) orelse {
                std.debug.print("Interacted with unknown window {d}, ignoring\n", .{window_id});
                return;
            };
            result.window.interacted = true;
        },
        else => {},
    }
}

//TODO keep track of the bindings and release them on shutdown
fn setKeyBinding(instance: *Instance, key: events.Key, modifiers: river.SeatV1.Modifiers, action: actions.Action) void {
    const binding = instance.xkb_bindings.?.getXkbBinding(instance.seat.?, @intFromEnum(key), modifiers) catch {
        std.debug.print("Failed to setup key binding\n", .{});
        return;
    };

    instance.actionMap.put(binding.getId(), action) catch {
        std.debug.print("Failed to store key binding\n", .{});
        return;
    };

    std.debug.print("Registering key binding {any}\n", .{action});
    binding.setListener(*Instance, keyBindingListener, instance);
    binding.enable();
}

fn keyBindingListener(
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
