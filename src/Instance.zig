const std = @import("std");
const wayland = @import("wayland");
const input = @import("input.zig");
const screen = @import("screen.zig");
const actions = @import("actions.zig");
const manage = @import("manage.zig");
const river = wayland.client.river;
const wl = wayland.client.wl;

const Instance = @This();

const InstanceError = error{
    WindowManagerNotFound,
};

exit: bool = false,
io: std.Io,
allocator: std.mem.Allocator,
display: *wl.Display,
registry: *wl.Registry,
window_manager: ?*river.WindowManagerV1 = null,
xkb_bindings: ?*river.XkbBindingsV1 = null,
layer_shell: ?*river.LayerShellV1 = null,
seat: ?*river.SeatV1 = null,
actionMap: std.AutoHashMap(u32, actions.Action),
windows: std.ArrayList(screen.Window),

pub fn init(io: std.Io, allocator: std.mem.Allocator) !*Instance {
    const instance = try allocator.create(Instance);
    const display = try wl.Display.connect(null);
    const registry = try display.getRegistry();

    instance.* = .{
        .io = io,
        .allocator = allocator,
        .display = display,
        .registry = registry,
        .actionMap = .init(instance.allocator),
        .windows = .empty,
    };

    instance.registry.setListener(*Instance, registryListener, instance);

    return instance;
}

pub fn deinit(instance: *Instance) void {
    //TODO iterate windows and destroy them?
    instance.windows.deinit(instance.allocator);
    instance.actionMap.deinit();
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

fn windowManagerListener(window_manager: *river.WindowManagerV1, event: river.WindowManagerV1.Event, instance: *Instance) void {
    switch (event) {
        .output => |output_event| {
            const output = output_event.id;
            output.setListener(*Instance, screen.outputListener, instance);
        },
        .seat => |seat_event| {
            input.handleNewSeat(instance, seat_event.id) catch |err| {
                std.debug.print("Error creating seat {}\n", .{err});
            };
        },
        .window => |window_event| {
            screen.handleNewWindow(instance, window_event.id) catch |err| {
                std.debug.print("Error opening window {}\n", .{err});
            };
        },
        .manage_start => {
            manage.handleManageStart(instance, window_manager) catch |err| {
                std.debug.print("Error during window management sequence {}\n", .{err});
            };
        },
        .render_start => window_manager.renderFinish(),
        .finished => {
            std.debug.print("Finished\n", .{});
            window_manager.destroy();
        },
        else => {},
    }
}
