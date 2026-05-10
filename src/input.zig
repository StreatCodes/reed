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

const Mapping = struct {
    action: actions.Action,
    binding: Binding,
};

const Binding = union(enum) {
    key: *river.XkbBindingV1,
    pointer: *river.PointerBindingV1,
};

pub const Seat = struct {
    river_seat: *river.SeatV1,
    action_map: std.AutoHashMap(u32, Mapping),
    hover: ?*Window = null,

    pub fn init(allocator: std.mem.Allocator, river_seat: *river.SeatV1) !*Seat {
        const seat = try allocator.create(Seat);
        seat.* = .{
            .river_seat = river_seat,
            .action_map = .init(allocator),
        };

        return seat;
    }

    pub fn deinit(seat: *Seat, allocator: std.mem.Allocator) void {
        var iterator = seat.action_map.iterator();

        while (iterator.next()) |mapping| {
            switch (mapping.value_ptr.binding) {
                .key => |binding| binding.destroy(),
                .pointer => |binding| binding.destroy(),
            }
        }

        seat.action_map.deinit();
        allocator.destroy(seat);
    }

    pub fn setKeyBinding(seat: *Seat, key: events.Key, modifiers: river.SeatV1.Modifiers, action: actions.Action) void {
        const instance = Instance.get();
        const binding = instance.xkb_bindings.?.getXkbBinding(seat.river_seat, @intFromEnum(key), modifiers) catch {
            std.debug.print("Failed to setup key binding\n", .{});
            return;
        };

        const mapping = Mapping{
            .action = action,
            .binding = .{ .key = binding },
        };
        seat.action_map.put(binding.getId(), mapping) catch {
            std.debug.print("Failed to store key binding map\n", .{});
            return;
        };

        std.debug.print("Registering key binding {any}\n", .{action});
        binding.setListener(*Seat, keyBindingListener, seat);
        binding.enable();
    }

    fn setPointerBinding(seat: *Seat, button: events.Mouse, modifiers: river.SeatV1.Modifiers, action: actions.Action) void {
        const binding = seat.river_seat.getPointerBinding(@intFromEnum(button), modifiers) catch {
            std.debug.print("Failed to setup pointer binding\n", .{});
            return;
        };

        const mapping = Mapping{
            .action = action,
            .binding = .{ .pointer = binding },
        };
        seat.action_map.put(binding.getId(), mapping) catch {
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
    const mapping = seat.action_map.get(xkb_binding.getId()) orelse {
        std.debug.print("Unknown binding {d}\n", .{xkb_binding.getId()});
        return;
    };

    switch (event) {
        .pressed => actions.execAction(mapping.action, .pressed),
        .released => actions.execAction(mapping.action, .released),
        .stop_repeat => actions.execAction(mapping.action, .stop_repeat),
    }
}

fn pointerBindingListener(
    pointer_binding: *river.PointerBindingV1,
    event: river.PointerBindingV1.Event,
    seat: *Seat,
) void {
    const mapping = seat.action_map.get(pointer_binding.getId()) orelse {
        std.debug.print("Unknown pointer binding {d}\n", .{pointer_binding.getId()});
        return;
    };

    switch (event) {
        .pressed => actions.execAction(mapping.action, .pressed),
        .released => actions.execAction(mapping.action, .released),
    }
}
