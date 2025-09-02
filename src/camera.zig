const std = @import("std");

const sdl = @import("sdl3");
const FRect = sdl.rect.FRect;

pub const Camera = struct {
    pub const Self = @This();

    viewport: FRect,

    pub fn init(window: sdl.video.Window) !Camera {
        const window_size = try window.getSizeInPixels();
        return .{
            .viewport = .{
                .x = 0,
                .y = 0,
                .w = @floatFromInt(window_size.width),
                .h = @floatFromInt(window_size.height),
            },
        };
    }

    pub fn setViewportSize(self: *Self, w: i32, h: i32) void {
        self.viewport.w = @floatFromInt(w);
        self.viewport.h = @floatFromInt(h);
    }

    pub fn intersects(self: *Self, rect: FRect) bool {
        return self.viewport.hasIntersection(rect);
    }
};
