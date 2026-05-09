const std = @import("std");
const Instance = @import("Instance.zig");
const events = @import("events.zig");

pub const Action = union(enum) {
    open: void,
    close: void,
    exit: void,
    mouse_test: void,
};

pub fn execAction(instance: *Instance, action: Action, event: events.Event) void {
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
        .mouse_test => std.debug.print("Mouse clicked!!! {}", .{event}),
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
