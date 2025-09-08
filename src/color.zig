const sdl = @import("sdl3");

pub const Color = struct {
    const Self = @This();

    r: u8 = 0,
    g: u8 = 0,
    b: u8 = 0,
    a: u8 = 255,

    pub const transparent: Color = .{ .a = 0 };
    pub const black: Color = .{};
    pub const red: Color = .{ .r = 255 };
    pub const green: Color = .{ .g = 255 };
    pub const blue: Color = .{ .b = 255 };

    pub fn into(self: *const Self) sdl.pixels.Color {
        return .{ .r = self.r, .g = self.g, .b = self.b, .a = self.a };
    }
};
