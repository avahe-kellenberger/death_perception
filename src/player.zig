const std = @import("std");
const Allocator = std.mem.Allocator;
const sdl = @import("sdl3");

const Surface = sdl.surface.Surface;
const Point = sdl.rect.Point(f32);

pub const Player = struct {
    pub const Self = @This();

    alloc: Allocator,

    loc: Point = .{ .x = 133, .y = 100 },
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
        _ = self;
        _ = dt;
        // self.loc.x += 1 * dt * 10;
        // self.loc.y += 1 * dt * 10;
    }

    pub fn render(self: *Self, ctx: Surface) !void {
        try self.image.blit(null, ctx, .{
            .x = @intFromFloat(self.loc.x - self.half_image_size.x),
            .y = @intFromFloat(self.loc.y - self.half_image_size.y),
        });
    }
};
