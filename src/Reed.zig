const std = @import("std");
const wayland = @import("wayland");
const keyboard = @import("keyboard.zig");
const river = wayland.client.river;
const wl = wayland.client.wl;

const Reed = @This();

const ReedError = error{
    WindowManagerNotFound,
};

exit: bool = false,
allocator: std.mem.Allocator,
display: *wl.Display,
registry: *wl.Registry,
window_manager: ?*river.WindowManagerV1 = null,
xkb_bindings: ?*river.XkbBindingsV1 = null,
layer_shell: ?*river.LayerShellV1 = null,
seat: ?*river.SeatV1 = null,
key_bindings: []*river.XkbBindingV1 = undefined,

pub fn init(allocator: std.mem.Allocator) !*Reed {
    const reed = try allocator.create(Reed);
    const display = try wl.Display.connect(null);
    const registry = try display.getRegistry();

    reed.* = .{
        .allocator = allocator,
        .display = display,
        .registry = registry,
    };

    reed.registry.setListener(*Reed, registryListener, reed);

    return reed;
}

pub fn deinit(reed: *Reed) void {
    reed.allocator.free(reed.key_bindings);
    if (reed.layer_shell) |layer_shell| layer_shell.destroy();
    if (reed.xkb_bindings) |xkb_bindings| xkb_bindings.destroy();
    if (reed.window_manager) |window_manager| {
        window_manager.exitSession();
        window_manager.destroy();
    }
    reed.registry.destroy();
    reed.display.disconnect();
    reed.allocator.destroy(reed);
}

pub fn run(reed: *Reed) void {
    while (!reed.exit) {
        _ = reed.display.flush();

        const err = reed.display.getError();
        if (err != 0) {
            std.debug.print("Wayland protocol error: {}\n", .{err});
            break;
        }

        const status = reed.display.dispatch();
        if (@intFromEnum(status) != 0) {
            std.debug.print("Program stopped with status: {}\n", .{status});
            break;
        }
    }
}

fn registryListener(registry: *wl.Registry, event: wl.Registry.Event, reed: *Reed) void {
    switch (event) {
        .global => |global| {
            const interface_name = std.mem.span(global.interface);
            if (std.mem.eql(u8, interface_name, "river_window_manager_v1")) {
                std.debug.print("Registering {s} {d}\n", .{ interface_name, global.version });
                const window_manager = registry.bind(global.name, river.WindowManagerV1, 4) catch return;
                window_manager.setListener(*Reed, windowManagerListener, reed);
                reed.window_manager = window_manager;
            } else if (std.mem.eql(u8, interface_name, "river_xkb_bindings_v1")) {
                std.debug.print("Registering {s} {d}\n", .{ interface_name, global.version });
                reed.xkb_bindings =
                    registry.bind(global.name, river.XkbBindingsV1, 2) catch null;
            } else if (std.mem.eql(u8, interface_name, "river_layer_shell_v1")) {
                std.debug.print("Registering {s} {d}\n", .{ interface_name, global.version });
                reed.layer_shell =
                    registry.bind(global.name, river.LayerShellV1, 1) catch null;
            }
        },
        .global_remove => |global| {
            std.debug.print("Removing {}\n", .{global.name});
        },
    }
}

fn windowManagerListener(
    window_manager: *river.WindowManagerV1,
    event: river.WindowManagerV1.Event,
    reed: *Reed,
) void {
    switch (event) {
        .output => |output_event| {
            std.debug.print("Available output {d}\n", .{output_event.id.getId()});
            // output_event.id.setListener(?*anyopaque, outputListener, null);
        },
        .seat => |seat_event| {
            std.debug.print("New seat event {d}\n", .{seat_event.id.getId()});
            reed.seat = seat_event.id;
            seat_event.id.setListener(*Reed, seatListener, reed);

            reed.initKeyBindings() catch |err| {
                std.debug.print("Failed to setup bindings {} \n", .{err});
            };
        },
        // .window => |window_event| {
        //     window.pending = window_event.id;
        //     window_event.id.setListener(*types.WindowManager, window.windowListener, &wm);
        // },
        .manage_start => {
            std.debug.print("Manage request\n", .{});
            window_manager.manageFinish();
        },
        .render_start => window_manager.renderFinish(),
        .finished => {
            std.debug.print("Finished\n", .{});
            window_manager.destroy();
        },
        else => {},
    }
}

fn seatListener(
    _: *river.SeatV1,
    event: river.SeatV1.Event,
    reed: *Reed,
) void {
    _ = reed;
    switch (event) {
        .window_interaction => |interaction| {
            _ = interaction;
            std.debug.print("Window interaction\n", .{});
        },

        else => {},
    }
}

fn initKeyBindings(reed: *Reed) !void {
    const xkb_bindings = reed.xkb_bindings orelse {
        std.debug.print("Failed to find xkb bindings\n", .{});
        return;
    };

    // TODO This is dumb, redo
    var keys: std.ArrayList(*river.XkbBindingV1) = .empty;

    // 0x0020 Spacebar
    const xkb_binding = xkb_bindings.getXkbBinding(
        reed.seat.?,
        0x0020,
        .{},
    ) catch |err| {
        std.debug.print("Failed to get xkb binding: {}\n", .{err});
        return;
    };

    try keys.append(reed.allocator, xkb_binding);
    reed.key_bindings = try keys.toOwnedSlice(reed.allocator);

    xkb_binding.setListener(*Reed, xkbBindingListener, reed);
    xkb_binding.enable();
}

fn xkbBindingListener(
    xkb_binding: *river.XkbBindingV1,
    event: river.XkbBindingV1.Event,
    reed: *Reed,
) void {
    switch (event) {
        .pressed => {
            std.debug.print("Key pressed {d}\n", .{xkb_binding.getId()});
            keyboard.handleKeyPressed(reed);
        },
        else => {},
    }
}
