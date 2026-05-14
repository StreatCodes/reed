const std = @import("std");
const wayland = @import("wayland");
const river = wayland.client.river;
const Instance = @import("Instance.zig");
const events = @import("events.zig");
const window = @import("window.zig");
const event_handlers = @import("event_handlers.zig");
const Window = window.Window;

const InputError = error{
    MultiSeatUnsupported,
};

const Binding = union(enum) {
    key: *river.XkbBindingV1,
    pointer: *river.PointerBindingV1,
};

/// These actions are handled in the manage sequence
const WindowAction = enum {
    move,
};

pub const Seat = struct {
    river_seat: *river.SeatV1,
    bindings: std.ArrayList(Binding) = .empty,
    hover: ?*Window = null,

    // TODO move these to their own struct
    op_action: ?WindowAction = null,
    op_released: bool = false,
    op_start_x: i32 = 0,
    op_start_y: i32 = 0,
    op_dx: i32 = 0,
    op_dy: i32 = 0,

    pub fn init(allocator: std.mem.Allocator, river_seat: *river.SeatV1) !*Seat {
        const seat = try allocator.create(Seat);
        seat.* = .{ .river_seat = river_seat };
        return seat;
    }

    pub fn deinit(seat: *Seat, allocator: std.mem.Allocator) void {
        for (seat.bindings.items) |binding| {
            switch (binding) {
                .key => |b| b.destroy(),
                .pointer => |b| b.destroy(),
            }
        }

        seat.bindings.deinit(allocator);
        allocator.destroy(seat);
    }

    pub fn startMoveWindow(seat: *Seat) void {
        if (seat.hover) |w| {
            seat.river_seat.opStartPointer();
            seat.op_action = .move;
            seat.op_start_x = w.x;
            seat.op_start_y = w.y;
            seat.op_dx = 0;
            seat.op_dy = 0;
        }
    }

    pub fn setKeyBinding(seat: *Seat, key: events.Key, modifiers: river.SeatV1.Modifiers, handler: event_handlers.KeyListener) void {
        const instance = Instance.get();
        const binding = instance.xkb_bindings.?.getXkbBinding(seat.river_seat, @intFromEnum(key), modifiers) catch {
            std.debug.print("Failed to setup key binding\n", .{});
            return;
        };

        seat.bindings.append(instance.allocator, .{ .key = binding }) catch {
            std.debug.print("Failed to store pointer binding\n", .{});
            binding.destroy();
            return;
        };

        std.debug.print("Registering key binding {any} {any}\n", .{ key, modifiers });
        binding.setListener(*Instance, handler, instance);
        binding.enable();
    }

    fn setPointerBinding(
        seat: *Seat,
        button: events.Mouse,
        modifiers: river.SeatV1.Modifiers,
        handler: event_handlers.PointerListener,
    ) void {
        const instance = Instance.get();
        const binding = seat.river_seat.getPointerBinding(@intFromEnum(button), modifiers) catch {
            std.debug.print("Failed to setup pointer binding\n", .{});
            return;
        };

        seat.bindings.append(instance.allocator, .{ .pointer = binding }) catch {
            std.debug.print("Failed to store pointer binding\n", .{});
            binding.destroy();
            return;
        };

        std.debug.print("Registering pointer binding {any} {any}\n", .{ button, modifiers });
        binding.setListener(*Instance, handler, instance);
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

    // Setup key bindings
    seat.setKeyBinding(.space, .{ .mod4 = true }, event_handlers.handleOpenLauncher);
    seat.setKeyBinding(.q, .{ .mod4 = true }, event_handlers.handleOpenLauncher);

    // Setup mouse bindings
    seat.setPointerBinding(.left, .{ .mod4 = true }, event_handlers.handleMoveWindow);
}

pub fn seatListener(_: *river.SeatV1, event: river.SeatV1.Event, instance: *Instance) void {
    const seat = instance.seat orelse return;
    switch (event) {
        .window_interaction => |interaction| {
            const window_id = interaction.window.?.getId();
            const result = window.getWindow(instance.windows.items, window_id) orelse {
                std.debug.print("Interacted with unknown window {d}, ignoring\n", .{window_id});
                return;
            };
            result.window.interacted = true;
        },
        .pointer_enter => |pointer_event| {
            const river_window = pointer_event.window orelse return;
            const result = window.getWindow(instance.windows.items, river_window.getId()) orelse {
                std.debug.print("Pointer entered unknown window {}, ignoring\n", .{river_window.getId()});
                return;
            };
            seat.hover = result.window;
        },
        .pointer_leave => {
            seat.hover = null;
        },
        .removed => {
            seat.deinit(instance.allocator);
            instance.seat = null;
        },
        .op_delta => |op| {
            seat.op_dx = op.dx;
            seat.op_dy = op.dy;
        },
        .op_release => {
            seat.op_released = true;
        },
        else => {},
    }
}
