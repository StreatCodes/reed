const std = @import("std");
const Instance = @import("Instance.zig");

pub const Action = union(enum) {
    open: void,
    close: void,
};

pub fn execAction(instance: *Instance, action: Action) void {
    _ = instance;

    switch (action) {
        .open => open(),
        .close => close(),
    }
}

fn open() void {
    std.debug.print("Open!!!\n", .{});
}

fn close() void {
    std.debug.print("Close!!!\n", .{});
}
