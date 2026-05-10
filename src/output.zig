const std = @import("std");
const wayland = @import("wayland");
const river = wayland.client.river;

pub fn handleNewOutput(output: *river.OutputV1) !void {
    output.setListener(?*anyopaque, outputListener, null);
}

//Not sure we even care about this stuff currently.
fn outputListener(output_v1: *river.OutputV1, event: river.OutputV1.Event, _: ?*anyopaque) void {
    _ = output_v1;

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
