const std = @import("std");
const Instance = @import("Instance.zig");
const events = @import("events.zig");

pub const Action = union(enum) {
    open: void,
    close: void,
    exit: void,
    move_window: void,
};

pub fn execAction(action: Action, event: events.Event) void {
    const instance = Instance.get();
    switch (action) {
        .open => {
            if (event == .pressed) {
                open(instance);
            }
        },
        .close => {
            if (event == .pressed) {
                close(instance);
            }
        },
        .exit => exit(instance),
        .move_window => {
            if (event == .pressed) {
                startMoveWindow(instance);
            }
        },
    }
}

fn open(instance: *Instance) void {
    const command = &[_][]const u8{"wmenu-run"};
    _ = std.process.spawn(instance.io, .{
        .argv = command,
        .pgid = 0,
    }) catch |err| {
        std.debug.print("Failed to open program {}\n", .{err});
    };
}

fn close(instance: *Instance) void {
    if (instance.windows.items.len == 0) return;
    const window = instance.windows.getLast();
    window.river_window.close();
}

fn exit(instance: *Instance) void {
    instance.exit = true;
}

pub fn startMoveWindow(instance: *Instance) void {
    const seat = instance.seat orelse return;
    if (seat.hover) |window| {
        seat.river_seat.opStartPointer();
        seat.op_action = .move;
        seat.op_start_x = window.x;
        seat.op_start_y = window.y;
        seat.op_dx = 0;
        seat.op_dy = 0;
    }
}
