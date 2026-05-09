pub const Event = enum {
    pressed,
    released,
    /// Keyboard only
    stop_repeat,
};

pub const Key = enum(u32) {
    space = 0x0020,
    tab = 0x0009,
    escape = 0x0FF1B,
    @"return" = 0x0FF0D,
    backspace = 0x0FF08,
    grave = 0x0060,
    tilde = 0x007E,

    @"0" = 0x0030,
    @"1" = 0x0031,
    @"2" = 0x0032,
    @"3" = 0x0033,
    @"4" = 0x0034,
    @"5" = 0x0035,
    @"6" = 0x0036,
    @"7" = 0x0037,
    @"8" = 0x0038,
    @"9" = 0x0039,

    a = 0x0061,
    b = 0x0062,
    c = 0x0063,
    d = 0x0064,
    e = 0x0065,
    f = 0x0066,
    g = 0x0067,
    h = 0x0068,
    i = 0x0069,
    j = 0x006A,
    k = 0x006B,
    l = 0x006C,
    m = 0x006D,
    n = 0x006E,
    o = 0x006F,
    p = 0x0070,
    q = 0x0071,
    r = 0x0072,
    s = 0x0073,
    t = 0x0074,
    u = 0x0075,
    v = 0x0076,
    w = 0x0077,
    x = 0x0078,
    y = 0x0079,
    z = 0x007A,

    f1 = 0xFFBE,
    f2 = 0xFFBF,
    f3 = 0xFFC0,
    f4 = 0xFFC1,
    f5 = 0xFFC2,
    f6 = 0xFFC3,
    f7 = 0xFFC4,
    f8 = 0xFFC5,
    f9 = 0xFFC6,
    f10 = 0xFFC7,
    f11 = 0xFFC8,
    f12 = 0xFFC9,

    left = 0xFF51,
    up = 0xFF52,
    right = 0xFF53,
    down = 0xFF54,
};

pub const Mouse = enum(u32) {
    left = 0x110, // BTN_LEFT
    right = 0x111, // BTN_RIGHT
    middle = 0x112, // BTN_MIDDLE
    side = 0x113, // BTN_SIDE
    extra = 0x114, // BTN_EXTRA
    forward = 0x115, // BTN_FORWARD
    back = 0x116, // BTN_BACK
};
