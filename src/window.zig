const std = @import("std");
const Instance = @import("Instance.zig");
const wayland = @import("wayland");
const actions = @import("actions.zig");
const river = wayland.client.river;

pub const Window = struct {
    id: u32 = undefined,
    title: []const u8 = "unknown",
    new: bool = true,
    interacted: bool = false,
    hover: bool = false,
    river_window: *river.WindowV1 = undefined,
    river_node: *river.NodeV1 = undefined,
    x: i32 = 200,
    y: i32 = 200,
    width: u32 = 600,
    height: u32 = 600,

    /// Should only be called in the manage or rendering sequence
    pub fn setPosition(window: *Window, x: i32, y: i32) void {
        window.x = x;
        window.y = y;
        window.river_node.setPosition(x, y);
    }
};

pub fn handleNewWindow(river_window: *river.WindowV1) !void {
    std.debug.print("New window ({d})\n", .{river_window.getId()});
    const instance = Instance.get();
    const river_node = try river_window.getNode();
    river_window.setListener(?*anyopaque, windowListener, null);

    const window = Window{
        .id = river_window.getId(),
        .river_window = river_window,
        .river_node = river_node,
    };

    try instance.windows.append(instance.allocator, window);
}

pub fn getWindow(windows: []Window, window_id: u32) ?struct { window: *Window, index: usize } {
    for (windows, 0..) |*window, index| {
        if (window.id == window_id) return .{ .window = window, .index = index };
    }
    return null;
}

pub fn windowListener(window_v1: *river.WindowV1, event: river.WindowV1.Event, _: ?*anyopaque) void {
    const instance = Instance.get();
    const result = getWindow(instance.windows.items, window_v1.getId()) orelse {
        std.debug.print("Received event from unknown window {}, ignoring\n", .{window_v1.getId()});
        return;
    };

    const window = result.window;
    const window_index = result.index;

    switch (event) {
        .title => |e| {
            if (e.title) |t| {
                window.title = std.mem.span(t);
            }
        },
        .dimensions => |dimensions| {
            std.debug.print("New window dimensions {d}x{d}\n", .{ dimensions.width, dimensions.height });
        },
        .closed => {
            std.debug.print("Closing window\n", .{});
            _ = instance.windows.orderedRemove(window_index);

            //Mark the last window as interacted so it gains focus.
            if (instance.windows.items.len > 0) {
                instance.windows.items[instance.windows.items.len - 1].interacted = true;
            }
        },
        .pointer_move_requested => |seat| {
            _ = seat;
            std.debug.print("Move requested\n", .{});
            actions.startMoveWindow(instance);
        },
        else => {},
    }
}
