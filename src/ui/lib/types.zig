const std = @import("std");

pub const StackDirection = enum {
    vertical,
    horizontal,
    overlap,
};

pub const SizeKind = enum {
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

pub const Insets = struct {
    const Self = @This();

    left: f32 = 0,
    top: f32 = 0,
    right: f32 = 0,
    bottom: f32 = 0,

    pub const zero: Self = .{};
    pub const inf: Self = .{
        .left = -std.math.inf(f32),
        .top = -std.math.inf(f32),
        .right = std.math.inf(f32),
        .bottom = std.math.inf(f32),
    };

    pub fn width(self: *const Self) f32 {
        return self.right - self.left;
    }

    pub fn height(self: *const Self) f32 {
        return self.bottom - self.top;
    }

    pub fn equals(self: *const Self, other: *const Self) bool {
        return self.left == other.left and self.top == other.top and self.right == other.right and self.bottom == other.bottom;
    }
};
