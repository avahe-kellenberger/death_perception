const std = @import("std");

const sdl = @import("sdl3");
const Renderer = sdl.render.Renderer;
const Texture = sdl.render.Texture;
const FRect = sdl.rect.FRect;
const FPoint = sdl.rect.FPoint;

const Game = @import("game.zig");
const Input = @import("input.zig");
const Vector = @import("vector.zig").Vector;

const max_speed = 65.0;

pub const Player = struct {
    pub const Self = @This();

    image: Texture,
    loc: FPoint = .{ .x = 0, .y = 0 },
    image_size: FPoint = undefined,

    pub fn init() Player {
        const image = Game.loadTexture("./assets/images/player.png", .nearest);
        return .{
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

    pub fn update(self: *Self, dt: f32) void {
        var vel: Vector = .{};
        if (Input.isKeyPressed(.left)) vel.x -= max_speed;
        if (Input.isKeyPressed(.right)) vel.x += max_speed;

        if (Input.isKeyPressed(.up)) vel.y -= max_speed;
        if (Input.isKeyPressed(.down)) vel.y += max_speed;

        vel = vel.maxMagnitude(max_speed);

        self.loc.x += vel.x * dt;
        self.loc.y += vel.y * dt;
    }

    pub fn render(self: *Self) void {
        Game.renderTexture(self.image, null, .{
            .x = self.loc.x - self.image_size.x * 0.5,
            .y = self.loc.y - self.image_size.y * 0.5,
            .w = self.image_size.x,
            .h = self.image_size.y,
        });
    }
};
