const std = @import("std");
const sdl = @import("sdl3");

pub const Vector = struct {
    pub const Self = @This();

    x: f32 = 0,
    y: f32 = 0,

    pub fn multiply(self: Self, scalar: f32) Vector {
        return .{
            .x = self.x * scalar,
            .y = self.y * scalar,
        };
    }

    pub fn getMagnitudeSquared(self: Self) f32 {
        return self.x * self.x + self.y * self.y;
    }

    pub fn getMagnitude(self: Self) f32 {
        return std.math.sqrt(self.getMagnitudeSquared());
    }

    pub fn maxMagnitude(self: Self, magnitude: f32) Vector {
        const currMagnitude = self.getMagnitude();
        if (currMagnitude <= magnitude) return self;

        return self.multiply(magnitude / currMagnitude);
    }
};
