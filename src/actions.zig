const std = @import("std");
const Instance = @import("Instance.zig");

pub const Action = union(enum) {
    open: void,
    close: void,
};

pub fn execAction(instance: *Instance, action: Action) void {
    switch (action) {
        .open => {
            open(instance) catch |err| {
                std.debug.print("Failed to open program {}\n", .{err});
            };
        },
        .close => close(),
    }
}

fn open(instance: *Instance) !void {
    const command = &[_][]const u8{"wmenu-run"};
    _ = try std.process.spawn(instance.io, .{ .argv = command });
}

fn close() void {
    std.debug.print("Close!!!\n", .{});
}
