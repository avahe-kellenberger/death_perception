const std = @import("std");
const Allocator = std.mem.Allocator;

const sdl = @import("sdl3");
const Renderer = sdl.render.Renderer;
const Texture = sdl.render.Texture;
const Point = sdl.rect.Point(f32);

const Input = @import("input.zig");
const Vector = @import("vector.zig").Vector;

const max_speed = 65.0;

pub const Player = struct {
    pub const Self = @This();

    alloc: Allocator,

    image: Texture,
    loc: Point = .{ .x = 0, .y = 0 },
    image_size: Point = undefined,

    pub fn init(alloc: Allocator, renderer: Renderer) !Player {
        const image = try sdl.image.loadTexture(renderer, "./assets/images/player.png");
        try image.setScaleMode(.nearest);
        return .{
            .alloc = alloc,
            .image = image,
            .image_size = .{
                .x = @as(f32, @floatFromInt(image.getWidth())),
                .y = @as(f32, @floatFromInt(image.getHeight())),
            },
        };
    }

    pub fn deinit(self: *Self) void {
        self.image.deinit();
    }

    pub fn update(self: *Self, dt: f32) !void {
        var vel: Vector = .{};
        if (Input.isPressed(.left)) vel.x -= max_speed;
        if (Input.isPressed(.right)) vel.x += max_speed;

        if (Input.isPressed(.up)) vel.y -= max_speed;
        if (Input.isPressed(.down)) vel.y += max_speed;

        vel = vel.maxMagnitude(max_speed);

        self.loc.x += vel.x * dt;
        self.loc.y += vel.y * dt;
    }

    pub fn render(self: *Self, ctx: Renderer, offset_x: f32, offset_y: f32) !void {
        try ctx.renderTexture(self.image, null, .{
            .x = self.loc.x - self.image_size.x * 0.5 + offset_x,
            .y = self.loc.y - self.image_size.y * 0.5 + offset_y,
            .w = self.image_size.x,
            .h = self.image_size.y,
        });
    }
};
