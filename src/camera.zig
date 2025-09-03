const std = @import("std");

const sdl = @import("sdl3");
const FRect = sdl.rect.FRect;
const FPoint = sdl.rect.FPoint;

const Size = @import("size.zig").Size;

pub const Camera = struct {
    pub const Self = @This();

    loc: FPoint,
    viewport: FRect,
    half_viewport_size: Size(f32),
    scaled_viewport: FRect,

    // Use setZoom to adjust camera zoom
    _z: f32 = 0,

    pub fn init(loc: FPoint, size: Size(f32)) !Camera {
        const viewport: FRect = .{
            .x = loc.x - size.w * 0.5,
            .y = loc.y - size.h * 0.5,
            .w = size.w,
            .h = size.h,
        };

        return .{
            .loc = loc,
            .viewport = viewport,
            .half_viewport_size = .{
                .w = viewport.w * 0.5,
                .h = viewport.h * 0.5,
            },
            .scaled_viewport = viewport,
        };
    }

    pub fn getZoom(self: *Self) f32 {
        return self._z;
    }

    pub fn setZoom(self: *Self, z: f32) void {
        self._z = z;
        self.adjustScaledViewport();
    }

    /// Increments zoom by dz.
    pub fn zoom(self: *Self, dz: f32) void {
        self._z += dz;
        self.adjustScaledViewport();
    }

    pub fn centerOnPoint(self: *Self, p: FPoint) void {
        self.loc = p;
        self.viewport.x = p.x - self.half_viewport_size.w;
        self.viewport.y = p.y - self.half_viewport_size.h;
        self.adjustScaledViewport();
    }

    pub fn setViewportSize(self: *Self, w: i32, h: i32) void {
        self.viewport.w = @floatFromInt(w);
        self.viewport.h = @floatFromInt(h);

        self.half_viewport_size = .{
            .w = self.viewport.w * 0.5,
            .h = self.viewport.h * 0.5,
        };

        self.viewport.x = self.loc.x - self.half_viewport_size.w;
        self.viewport.y = self.loc.y - self.half_viewport_size.h;
        self.adjustScaledViewport();
    }

    fn adjustScaledViewport(self: *Self) void {
        const relative_z = 1.0 - self._z;
        // Viewport is not visible in this case
        if (relative_z <= 0) return;

        self.scaled_viewport.x = self.loc.x - self.half_viewport_size.w * relative_z;
        self.scaled_viewport.y = self.loc.y - self.half_viewport_size.h * relative_z;
        self.scaled_viewport.w = self.viewport.w * relative_z;
        self.scaled_viewport.h = self.viewport.h * relative_z;
    }

    pub fn intersects(self: *Self, rect: FRect) bool {
        // return self.scaled_viewport.hasIntersection(rect);
        return self.viewport.hasIntersection(rect);
    }
};
