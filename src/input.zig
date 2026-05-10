const std = @import("std");
const wayland = @import("wayland");
const river = wayland.client.river;
const Instance = @import("Instance.zig");
const actions = @import("actions.zig");
const events = @import("events.zig");
const window = @import("window.zig");
const Window = window.Window;

const InputError = error{
    MultiSeatUnsupported,
};

//TODO remove key_bindings, pointer bindings, update action_map to be a struct with the binding on it
pub const Seat = struct {
    river_seat: *river.SeatV1,
    action_map: std.AutoHashMap(u32, actions.Action),
    key_bindings: std.ArrayList(*river.XkbBindingV1),
    pointer_bindings: std.ArrayList(*river.PointerBindingV1),
    hover: ?*Window = null,

    pub fn init(allocator: std.mem.Allocator, river_seat: *river.SeatV1) !*Seat {
        const seat = try allocator.create(Seat);
        seat.* = .{
            .river_seat = river_seat,
            .action_map = .init(allocator),
            .key_bindings = .empty,
            .pointer_bindings = .empty,
        };

        return seat;
    }

    pub fn deinit(seat: *Seat, allocator: std.mem.Allocator) void {
        for (seat.key_bindings.items) |binding| {
            binding.destroy();
        }
        seat.key_bindings.deinit(allocator);
        for (seat.pointer_bindings.items) |binding| {
            binding.destroy();
        }
        seat.pointer_bindings.deinit(allocator);
        seat.action_map.deinit();
        allocator.destroy(seat);
    }

    pub fn setKeyBinding(seat: *Seat, key: events.Key, modifiers: river.SeatV1.Modifiers, action: actions.Action) void {
        const instance = Instance.get();
        const binding = instance.xkb_bindings.?.getXkbBinding(seat.river_seat, @intFromEnum(key), modifiers) catch {
            std.debug.print("Failed to setup key binding\n", .{});
            return;
        };

        seat.key_bindings.append(instance.allocator, binding) catch {
            std.debug.print("Failed to store key binding\n", .{});
            return;
        };
        seat.action_map.put(binding.getId(), action) catch {
            std.debug.print("Failed to store key binding map\n", .{});
            return;
        };

        std.debug.print("Registering key binding {any}\n", .{action});
        binding.setListener(*Seat, keyBindingListener, seat);
        binding.enable();
    }

    fn setPointerBinding(seat: *Seat, button: events.Mouse, modifiers: river.SeatV1.Modifiers, action: actions.Action) void {
        const instance = Instance.get();
        const binding = seat.river_seat.getPointerBinding(@intFromEnum(button), modifiers) catch {
            std.debug.print("Failed to setup pointer binding\n", .{});
            return;
        };

        seat.pointer_bindings.append(instance.allocator, binding) catch {
            std.debug.print("Failed to store pointer binding\n", .{});
            return;
        };
        seat.action_map.put(binding.getId(), action) catch {
            std.debug.print("Failed to store pointer binding map\n", .{});
            return;
        };

        std.debug.print("Registering pointer binding {any}\n", .{action});
        binding.setListener(*Seat, pointerBindingListener, seat);
        binding.enable();
    }
};

pub fn handleNewSeat(river_seat: *river.SeatV1) !void {
    const instance = Instance.get();
    std.debug.print("New seat {d}\n", .{river_seat.getId()});

    if (instance.seat != null) {
        return InputError.MultiSeatUnsupported;
    }

    var seat = try Seat.init(instance.allocator, river_seat);
    instance.seat = seat;
    river_seat.setListener(*Instance, seatListener, instance);

    // Hard coded for now
    seat.setKeyBinding(.space, .{ .mod4 = true }, .open);
    seat.setKeyBinding(.q, .{ .mod4 = true }, .close);

    //TODO apply other mouse bindings here
    seat.setPointerBinding(.left, .{ .mod4 = true }, .move_window);
}

pub fn seatListener(_: *river.SeatV1, event: river.SeatV1.Event, instance: *Instance) void {
    switch (event) {
        .window_interaction => |interaction| {
            const window_id = interaction.window.?.getId();
            const result = window.getWindow(instance.windows.items, window_id) orelse {
                std.debug.print("Interacted with unknown window {d}, ignoring\n", .{window_id});
                return;
            };
            result.window.interacted = true;
        },
        .removed => {
            instance.seat.?.deinit(instance.allocator);
            instance.seat = null;
        },
        else => {},
    }
}

fn keyBindingListener(
    xkb_binding: *river.XkbBindingV1,
    event: river.XkbBindingV1.Event,
    seat: *Seat,
) void {
    const action = seat.action_map.get(xkb_binding.getId()) orelse {
        std.debug.print("Unknown binding {d}\n", .{xkb_binding.getId()});
        return;
    };

    switch (event) {
        .pressed => actions.execAction(action, .pressed),
        .released => actions.execAction(action, .released),
        .stop_repeat => actions.execAction(action, .stop_repeat),
    }
}

fn pointerBindingListener(
    pointer_binding: *river.PointerBindingV1,
    event: river.PointerBindingV1.Event,
    seat: *Seat,
) void {
    const action = seat.action_map.get(pointer_binding.getId()) orelse {
        std.debug.print("Unknown pointer binding {d}\n", .{pointer_binding.getId()});
        return;
    };

    switch (event) {
        .pressed => actions.execAction(action, .pressed),
        .released => actions.execAction(action, .released),
    }
}
