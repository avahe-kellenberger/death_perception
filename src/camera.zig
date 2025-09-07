const std = @import("std");

const sdl = @import("sdl3");
const FRect = sdl.rect.FRect;
const Vector = @import("math/vector.zig").Vector(f32);

const Size = @import("size.zig").Size;

const DEFAULT_Z: f32 = 1.0;

pub const Camera = struct {
    pub const Self = @This();

    /// Center of camera (in game coordinates)
    _loc: Vector,

    // Camera size (in screen coordinates)
    _size: Size(f32),

    // Camera zoom
    _z: f32 = 0,

    /// Outer bounds of camera (in game coordinates)
    viewport: FRect = .{ .x = 0, .y = 0, .w = 0, .h = 0 },

    pub fn init(loc: Vector, size: Size(f32)) Camera {
        var cam: Camera = .{
            ._loc = loc,
            ._size = size,
        };
        cam.updateViewport();
        return cam;
    }

    pub fn getScale(self: *Self) ?f32 {
        const relative_z = DEFAULT_Z - self._z;
        if (relative_z <= 0) return null;
        return 1.0 / relative_z;
    }

    pub fn centerOnPoint(self: *Self, p: Vector) void {
        self._loc = p;
        self.updateViewport();
    }

    pub fn setSize(self: *Self, w: f32, h: f32) void {
        self._size.w = w;
        self._size.h = h;
        self.updateViewport();
    }

    pub fn zoom(self: *Self, z: f32) void {
        self._z += z;
        self.updateViewport();
    }

    fn updateViewport(self: *Self) void {
        if (self.getScale()) |scale| {
            self.viewport.w = self._size.w / scale;
            self.viewport.h = self._size.h / scale;
            self.viewport.x = self._loc.x - (self.viewport.w * 0.5);
            self.viewport.y = self._loc.y - (self.viewport.h * 0.5);
        }
    }

    pub fn intersects(self: *Self, rect: FRect) bool {
        return self.viewport.hasIntersection(rect);
    }

    pub fn screenToWorld(self: *Self, p: Vector) Vector {
        const relative_z = DEFAULT_Z - self._z;
        return .{
            .x = (p.x * relative_z) + self._loc.x - self.viewport.w * 0.5,
            .y = (p.y * relative_z) + self._loc.y - self.viewport.h * 0.5,
        };
    }
};
