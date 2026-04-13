const wayland = @import("wayland");
const river = wayland.client.river;
const wl = wayland.client.wl;

const Reed = @This();

display: *wl.Display,

pub fn init() !Reed {
    return .{
        .display = try wl.Display.connect(null),
    };
}

pub fn deinit(reed: *Reed) void {
    reed.display.disconnect();
}
