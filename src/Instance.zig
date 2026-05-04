const std = @import("std");
const wayland = @import("wayland");
const keyboard = @import("keyboard.zig");
const river = wayland.client.river;
const wl = wayland.client.wl;

const Instance = @This();

const InstanceError = error{
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

pub fn init(allocator: std.mem.Allocator) !*Instance {
    const instance = try allocator.create(Instance);
    const display = try wl.Display.connect(null);
    const registry = try display.getRegistry();

    instance.* = .{
        .allocator = allocator,
        .display = display,
        .registry = registry,
    };

    instance.registry.setListener(*Instance, registryListener, instance);

    return instance;
}

pub fn deinit(instance: *Instance) void {
    instance.allocator.free(instance.key_bindings);
    if (instance.layer_shell) |layer_shell| layer_shell.destroy();
    if (instance.xkb_bindings) |xkb_bindings| xkb_bindings.destroy();
    if (instance.window_manager) |window_manager| {
        window_manager.exitSession();
        window_manager.destroy();
    }
    instance.registry.destroy();
    instance.display.disconnect();
    instance.allocator.destroy(instance);
}

pub fn run(instance: *Instance) void {
    while (!instance.exit) {
        _ = instance.display.flush();

        const err = instance.display.getError();
        if (err != 0) {
            std.debug.print("Wayland protocol error: {}\n", .{err});
            break;
        }

        const status = instance.display.dispatch();
        if (@intFromEnum(status) != 0) {
            std.debug.print("Program stopped with status: {}\n", .{status});
            break;
        }
    }
}

fn registryListener(registry: *wl.Registry, event: wl.Registry.Event, instance: *Instance) void {
    switch (event) {
        .global => |global| {
            const interface_name = std.mem.span(global.interface);
            if (std.mem.eql(u8, interface_name, "river_window_manager_v1")) {
                std.debug.print("Registering {s} {d}\n", .{ interface_name, global.version });
                const window_manager = registry.bind(global.name, river.WindowManagerV1, 4) catch return;
                window_manager.setListener(*Instance, windowManagerListener, instance);
                instance.window_manager = window_manager;
            } else if (std.mem.eql(u8, interface_name, "river_xkb_bindings_v1")) {
                std.debug.print("Registering {s} {d}\n", .{ interface_name, global.version });
                instance.xkb_bindings =
                    registry.bind(global.name, river.XkbBindingsV1, 2) catch null;
            } else if (std.mem.eql(u8, interface_name, "river_layer_shell_v1")) {
                std.debug.print("Registering {s} {d}\n", .{ interface_name, global.version });
                instance.layer_shell =
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
    instance: *Instance,
) void {
    switch (event) {
        .output => |output_event| {
            std.debug.print("Available output {d}\n", .{output_event.id.getId()});
            // output_event.id.setListener(?*anyopaque, outputListener, null);
        },
        .seat => |seat_event| {
            std.debug.print("New seat event {d}\n", .{seat_event.id.getId()});
            instance.seat = seat_event.id;
            seat_event.id.setListener(*Instance, seatListener, instance);

            instance.initKeyBindings() catch |err| {
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
    instance: *Instance,
) void {
    _ = instance;
    switch (event) {
        .window_interaction => |interaction| {
            _ = interaction;
            std.debug.print("Window interaction\n", .{});
        },

        else => {},
    }
}

fn initKeyBindings(instance: *Instance) !void {
    const xkb_bindings = instance.xkb_bindings orelse {
        std.debug.print("Failed to find xkb bindings\n", .{});
        return;
    };

    // TODO This is dumb, redo
    var keys: std.ArrayList(*river.XkbBindingV1) = .empty;

    // 0x0020 Spacebar
    const xkb_binding = xkb_bindings.getXkbBinding(
        instance.seat.?,
        0x0020,
        .{},
    ) catch |err| {
        std.debug.print("Failed to get xkb binding: {}\n", .{err});
        return;
    };

    try keys.append(instance.allocator, xkb_binding);
    instance.key_bindings = try keys.toOwnedSlice(instance.allocator);

    xkb_binding.setListener(*Instance, xkbBindingListener, instance);
    xkb_binding.enable();
}

fn xkbBindingListener(
    xkb_binding: *river.XkbBindingV1,
    event: river.XkbBindingV1.Event,
    instance: *Instance,
) void {
    switch (event) {
        .pressed => {
            std.debug.print("Key pressed {d}\n", .{xkb_binding.getId()});
            keyboard.handleKeyPressed(instance);
        },
        else => {},
    }
}
