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

    // Camera zoom
    z: f32 = 0,

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
        };
    }

    pub fn centerOnPoint(self: *Self, p: FPoint) void {
        self.loc = p;
        self.viewport.x = p.x - self.half_viewport_size.w;
        self.viewport.y = p.y - self.half_viewport_size.h;
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
    }

    pub fn intersects(self: *Self, rect: FRect) bool {
        return self.viewport.hasIntersection(rect);
    }
};
