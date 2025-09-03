const std = @import("std");

const sdl = @import("sdl3");
const Renderer = sdl.render.Renderer;
const Texture = sdl.render.Texture;
const FRect = sdl.rect.FRect;
const FPoint = sdl.rect.FPoint;

const Camera = @import("camera.zig").Camera;

pub const RenderContext = struct {
    pub const Self = @This();

    renderer: Renderer,
    camera: *Camera,
    offset: FPoint = .{ .x = 0, .y = 0 },

    pub fn init(renderer: Renderer, camera: *Camera) Self {
        return .{ .renderer = renderer, .camera = camera };
    }

    pub fn renderTexture(self: *Self, t: Texture, src: ?FRect, dst: ?*FRect) !void {
        if (dst) |d| if (self.camera.intersects(d.*)) {
            // NOTE: I assume this is better than creating an entirely new rect,
            // but it is odd needing to pass in a pointer.
            d.x += self.offset.x;
            defer d.x -= self.offset.x;

            d.y += self.offset.y;
            defer d.y -= self.offset.y;

            try self.renderer.renderTexture(t, src, d.*);
        };
    }
};
