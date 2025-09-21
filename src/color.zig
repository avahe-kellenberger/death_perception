const sdl_ = @import("sdl3");

const WithColor = struct {
    r: ?u8 = null,
    g: ?u8 = null,
    b: ?u8 = null,
    a: ?u8 = null,
};

pub const Color = struct {
    const Self = @This();

    r: u8 = 0,
    g: u8 = 0,
    b: u8 = 0,
    a: u8 = 255,

    pub const transparent: Color = .{ .a = 0 };
    pub const black: Color = .{};
    pub const white: Color = .{ .r = 255, .g = 255, .b = 255 };
    pub const red: Color = .{ .r = 255 };
    pub const green: Color = .{ .g = 255 };
    pub const blue: Color = .{ .b = 255 };

    pub fn with(self: *const Self, w: WithColor) Self {
        var c = self.*;
        if (w.r) |r| c.r = r;
        if (w.g) |g| c.g = g;
        if (w.b) |b| c.b = b;
        if (w.a) |a| c.a = a;
        return c;
    }

    pub fn sdl(self: *const Self) sdl_.pixels.Color {
        return .{ .r = self.r, .g = self.g, .b = self.b, .a = self.a };
    }

    pub fn ttf(self: *const Self) sdl_.ttf.Color {
        return .{ .r = self.r, .g = self.g, .b = self.b, .a = self.a };
    }
};
