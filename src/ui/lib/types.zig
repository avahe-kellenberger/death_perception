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

    pub fn size(self: *const Self) Vector {
        return .init(self.width(), self.height());
    }

    pub fn center(self: *const Self) Vector {
        return .init(
            (self.left + self.right) / 2.0,
            (self.top + self.bottom) / 2.0,
        );
    }

    pub fn contains(self: *const Self, x: f32, y: f32) bool {
        return x >= self.left and y >= self.top and x < self.right and y < self.bottom;
    }

    pub fn intersect(self: *const Self, other: *const Self) Self {
        return .{
            .left = @max(self.left, other.left),
            .top = @max(self.top, other.top),
            .right = @min(self.right, other.right),
            .bottom = @min(self.bottom, other.bottom),
        };
    }

    pub fn frect(self: *const Self) sdl.rect.FRect {
        return .{
            .x = self.left,
            .y = self.top,
            .w = self.right - self.left,
            .h = self.bottom - self.top,
        };
    }

    pub fn irect(self: *const Self) sdl.rect.IRect {
        const floor_left: i32 = @intFromFloat(@floor(self.left));
        const floor_top: i32 = @intFromFloat(@floor(self.top));
        const ceil_right: i32 = @intFromFloat(@ceil(self.right));
        const ceil_bottom: i32 = @intFromFloat(@ceil(self.bottom));
        return .{
            .x = floor_left,
            .y = floor_top,
            .w = ceil_right - floor_left,
            .h = ceil_bottom - floor_top,
        };
    }

    pub fn equals(self: *const Self, other: *const Self) bool {
        return self.left == other.left and self.top == other.top and self.right == other.right and self.bottom == other.bottom;
    }
};
