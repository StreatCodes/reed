const std = @import("std");
const wayland = @import("wayland");
const input = @import("input.zig");
const output = @import("output.zig");
const manage = @import("manage.zig");
const render = @import("render.zig");
const window = @import("window.zig");
const river = wayland.client.river;
const wl = wayland.client.wl;
const Window = window.Window;

/// Instance is a singleton
const Instance = @This();
var _instance: *Instance = undefined;

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
compositor: ?*wl.Compositor = null,
seat: ?*input.Seat = null,
windows: std.ArrayList(Window),

pub fn get() *Instance {
    return _instance;
}

pub fn init(io: std.Io, allocator: std.mem.Allocator) !*Instance {
    _instance = try allocator.create(Instance);
    const display = try wl.Display.connect(null);
    const registry = try display.getRegistry();

    _instance.* = .{
        .io = io,
        .allocator = allocator,
        .display = display,
        .registry = registry,
        .windows = .empty,
    };

    _instance.registry.setListener(?*anyopaque, registryListener, null);
    return _instance;
}

pub fn deinit(instance: *Instance) void {
    instance.windows.deinit(instance.allocator);
    if (instance.seat) |seat| seat.deinit(instance.allocator);
    if (instance.window_manager) |window_manager| {
        window_manager.exitSession();
        const result = instance.display.flush();
        if (result != .SUCCESS) {
            std.debug.print("Failed to flush exit event, exit status {d}\n", .{result});
        }
    }
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

fn registryListener(registry: *wl.Registry, event: wl.Registry.Event, _: ?*anyopaque) void {
    const instance = get();
    switch (event) {
        .global => |global| {
            const interface_name = std.mem.span(global.interface);

            if (std.mem.eql(u8, interface_name, "river_window_manager_v1")) {
                std.debug.print("Registering {s} v{d}\n", .{ interface_name, global.version });
                const window_manager = registry.bind(global.name, river.WindowManagerV1, 4) catch {
                    @panic("Failed to register river_window_manager_v1");
                };
                window_manager.setListener(?*anyopaque, windowManagerListener, null);
                instance.window_manager = window_manager;
                return;
            }

            if (std.mem.eql(u8, interface_name, "river_xkb_bindings_v1")) {
                std.debug.print("Registering {s} v{d}\n", .{ interface_name, global.version });
                const xkb_bindings = registry.bind(global.name, river.XkbBindingsV1, 2) catch {
                    @panic("Failed to register river_xkb_bindings_v1");
                };
                instance.xkb_bindings = xkb_bindings;
                return;
            }

            if (std.mem.eql(u8, interface_name, "river_layer_shell_v1")) {
                std.debug.print("Registering {s} v{d}\n", .{ interface_name, global.version });
                const layer_shell =
                    registry.bind(global.name, river.LayerShellV1, 1) catch {
                        @panic("Failed to register river_layer_shell_v1");
                    };
                instance.layer_shell = layer_shell;
                return;
            }

            if (std.mem.eql(u8, interface_name, "wl_compositor")) {
                std.debug.print("Registering {s} v{d}\n", .{ interface_name, global.version });
                const compositor =
                    registry.bind(global.name, wl.Compositor, 6) catch {
                        @panic("Failed to register wl_compositor");
                    };
                instance.compositor = compositor;
                return;
            }
        },
        .global_remove => |global| {
            std.debug.print("Removing {}\n", .{global.name});
        },
    }
}

fn windowManagerListener(window_manager: *river.WindowManagerV1, event: river.WindowManagerV1.Event, _: ?*anyopaque) void {
    switch (event) {
        .output => |output_event| {
            output.handleNewOutput(output_event.id) catch |err| {
                std.debug.print("Error creating output {}\n", .{err});
            };
        },
        .seat => |seat_event| {
            input.handleNewSeat(seat_event.id) catch |err| {
                std.debug.print("Error creating seat {}\n", .{err});
            };
        },
        .window => |window_event| {
            window.handleNewWindow(window_event.id) catch |err| {
                std.debug.print("Error opening window {}\n", .{err});
            };
        },
        .manage_start => {
            manage.handleManageStart(window_manager) catch |err| {
                std.debug.print("Error during window management sequence {}\n", .{err});
            };
        },
        .render_start => {
            render.handleRenderStart(window_manager) catch |err| {
                std.debug.print("Error during window render sequence {}\n", .{err});
            };
        },
        .finished => {
            std.debug.print("Finished\n", .{});
            window_manager.destroy();
        },
        else => {},
    }
}
