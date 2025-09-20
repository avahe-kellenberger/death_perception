const std = @import("std");
const sdl = @import("sdl3");

const Vector = @import("../../math/vector.zig").Vector(f32);

pub const StackDirection = enum(u2) {
    vertical,
    horizontal,
    overlap,
};

pub const SizeKind = enum(u1) {
    pixel,
    ratio,
};

pub const Size = union(SizeKind) {
    const Self = @This();

    pixel: f32,
    ratio: f32, // 0.0 to 1.0, inclusive

    pub fn equals(self: Self, other: Self) bool {
        if (self == .pixel and other == .pixel) {
            return self.pixel == other.pixel;
        } else if (self == .ratio and other == .ratio) {
            return self.ratio == other.ratio;
        } else {
            return false;
        }
    }

    pub fn pixelSize(self: Self, available_parent_size: f32) f32 {
        return switch (self) {
            .pixel => |p| p,
            .ratio => |r| r * available_parent_size,
        };
    }
};
