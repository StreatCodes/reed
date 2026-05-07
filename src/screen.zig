const std = @import("std");
const wayland = @import("wayland");
const river = wayland.client.river;
const wl = wayland.client.wl;
const Instance = @import("Instance.zig");
const actions = @import("actions.zig");

//Not sure we even care about this stuff currently.
pub fn outputListener(output_v1: *river.OutputV1, event: river.OutputV1.Event, instance: *Instance) void {
    _ = output_v1;
    _ = instance;

    switch (event) {
        .position => |pos| {
            std.debug.print("Output position {d}x{d}\n", .{ pos.x, pos.y });
        },
        .dimensions => |dimensions| {
            std.debug.print("Output dimensions {d}x{d}\n", .{ dimensions.width, dimensions.height });
        },
        else => {},
    }
}

pub const Window = struct {
    new: bool = true,
    river_window: *river.WindowV1 = undefined,
    river_node: *river.NodeV1 = undefined,
    x: i32 = 200,
    y: i32 = 200,
    width: u32 = 600,
    height: u32 = 600,
};

pub fn handleNewWindow(instance: *Instance, river_window: *river.WindowV1) !void {
    std.debug.print("New window ({d})\n", .{river_window.getId()});
    const river_node = try river_window.getNode();
    river_window.setListener(*Instance, windowListener, instance);

    const window = Window{
        .river_window = river_window,
        .river_node = river_node,
    };

    try instance.windows.append(instance.allocator, window);
    river_node.placeTop();
}

pub fn windowListener(window_v1: *river.WindowV1, event: river.WindowV1.Event, instance: *Instance) void {
    _ = window_v1;
    _ = instance;

    switch (event) {
        .title => |e| {
            std.debug.print("New window title {any}\n", .{e.title});
        },
        .dimensions => |dimensions| {
            std.debug.print("New window dimensions {d}x{d}\n", .{ dimensions.width, dimensions.height });
        },
        else => {},
    }
}
