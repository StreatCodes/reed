const std = @import("std");
const wayland = @import("wayland");
const river = wayland.client.river;
const wl = wayland.client.wl;

const Reed = @This();

display: *wl.Display,
registry: *wl.Registry,
window_manager: ?*river.WindowManagerV1 = null,
xkb_bindings: ?*river.XkbBindingsV1 = null,
layer_shell: ?*river.LayerShellV1 = null,

pub fn init() !Reed {
    const display = try wl.Display.connect(null);
    const registry = try display.getRegistry();

    var reed = Reed{
        .display = display,
        .registry = registry,
    };

    registry.setListener(*Reed, registryListener, &reed);
    if (display.roundtrip() != .SUCCESS) return error.RoundtripFailed;

    return reed;
}

pub fn deinit(reed: *Reed) void {
    if (reed.layer_shell) |layer_shell| layer_shell.destroy();
    if (reed.xkb_bindings) |xkb_bindings| xkb_bindings.destroy();
    if (reed.window_manager) |window_manager| window_manager.destroy();
    reed.registry.destroy();
    reed.display.disconnect();
}

fn registryListener(registry: *wl.Registry, event: wl.Registry.Event, reed: *Reed) void {
    switch (event) {
        .global => |global| {
            const interface_name = std.mem.span(global.interface);
            if (std.mem.eql(u8, interface_name, "river_window_manager_v1")) {
                std.debug.print("Registering {s}\n", .{interface_name});
                reed.window_manager =
                    registry.bind(global.name, river.WindowManagerV1, 4) catch null;
            } else if (std.mem.eql(u8, interface_name, "river_xkb_bindings_v1")) {
                std.debug.print("Registering {s}\n", .{interface_name});
                reed.xkb_bindings =
                    registry.bind(global.name, river.XkbBindingsV1, 2) catch null;
            } else if (std.mem.eql(u8, interface_name, "river_layer_shell_v1")) {
                std.debug.print("Registering {s}\n", .{interface_name});
                reed.layer_shell =
                    registry.bind(global.name, river.LayerShellV1, 1) catch null;
            }
        },
        .global_remove => {},
    }
}
