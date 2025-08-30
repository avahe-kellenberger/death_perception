const std = @import("std");
const Allocator = std.mem.Allocator;
const sdl = @import("sdl3");

const Surface = sdl.surface.Surface;
const Point = sdl.rect.Point(f32);

const input = @import("input.zig");
const Vector = @import("vector.zig").Vector;

const max_speed = 65.0;

pub const Player = struct {
    pub const Self = @This();

    alloc: Allocator,

    loc: Point = .{ .x = 400, .y = 300 },
    image: Surface,
    half_image_size: Point = undefined,

    pub fn init(alloc: Allocator) !Player {
        const image = try sdl.image.loadFile("./assets/images/player.png");
        return .{
            .alloc = alloc,
            .image = image,
            .half_image_size = .{
                .x = @as(f32, @floatFromInt(image.getWidth())) * 0.5,
                .y = @as(f32, @floatFromInt(image.getHeight())) * 0.5,
            },
        };
    }

    pub fn deinit(self: *Self) void {
        self.image.deinit();
    }

    pub fn update(self: *Self, dt: f32) !void {
        var vel: Vector = .{};
        if (input.handler.isPressed(.left)) vel.x -= max_speed;
        if (input.handler.isPressed(.right)) vel.x += max_speed;

        if (input.handler.isPressed(.up)) vel.y -= max_speed;
        if (input.handler.isPressed(.down)) vel.y += max_speed;

        vel = vel.maxMagnitude(max_speed);

        self.loc.x += vel.x * dt;
        self.loc.y += vel.y * dt;
    }

    pub fn render(self: *Self, ctx: Surface) !void {
        try self.image.blit(null, ctx, .{
            .x = @intFromFloat(self.loc.x - self.half_image_size.x),
            .y = @intFromFloat(self.loc.y - self.half_image_size.y),
        });
    }
};
