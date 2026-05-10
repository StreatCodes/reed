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
                open();
            }
        },
        .close => {
            if (event == .pressed) {
                close();
            }
        },
        .exit => exit(),
        .move_window => instance.seat.?.pending_action = .move,
    }
}

fn open() void {
    const instance = Instance.get();
    const command = &[_][]const u8{"wmenu-run"};
    _ = std.process.spawn(instance.io, .{
        .argv = command,
        .pgid = 0,
    }) catch |err| {
        std.debug.print("Failed to open program {}\n", .{err});
    };
}

fn close() void {
    const instance = Instance.get();
    if (instance.windows.items.len == 0) return;
    const window = instance.windows.getLast();
    window.river_window.close();
}

fn exit() void {
    const instance = Instance.get();
    instance.exit = true;
}
