const std = @import("std");
const Instance = @import("Instance.zig");

pub const Action = union(enum) {
    open: void,
    close: void,
    exit: void,
};

pub fn execAction(instance: *Instance, action: Action) void {
    switch (action) {
        .open => {
            open(instance) catch |err| {
                std.debug.print("Failed to open program {}\n", .{err});
            };
        },
        .close => close(),
        .exit => exit(instance),
    }
}

fn open(instance: *Instance) !void {
    const command = &[_][]const u8{"wmenu-run"};
    _ = try std.process.spawn(instance.io, .{
        .argv = command,
        .pgid = 0,
    });
}

fn close() void {
    std.debug.print("Close!!!\n", .{});
}

fn exit(instance: *Instance) void {
    instance.exit = true;
}
