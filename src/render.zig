const std = @import("std");
const wayland = @import("wayland");
const Instance = @import("Instance.zig");
const river = wayland.client.river;

/// TODO add logic for title bars in here
pub fn handleRenderStart(window_manager: *river.WindowManagerV1) !void {
    const instance = Instance.get();
    _ = instance;

    // for(instance.windows.items) |window| {
    //     if(window.decoration_surface) |surface| {
    //         surface.
    //     }
    // }

    window_manager.renderFinish();
}
