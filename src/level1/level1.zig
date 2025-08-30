const std = @import("std");
const Allocator = std.mem.Allocator;

const sdl = @import("sdl3");
const Player = @import("../player.zig").Player;

pub const Level1 = struct {
    pub const Self = @This();

    alloc: Allocator,

    player: Player,

    pub fn init(alloc: Allocator) !Level1 {
        return .{
            .alloc = alloc,
            .player = try Player.init(alloc),
        };
    }

    pub fn deinit(self: *Self) void {
        self.player.deinit();
    }

    pub fn update(self: *Self, dt: f32) !void {
        try self.player.update(dt);
    }

    pub fn render(self: *Self, ctx: sdl.surface.Surface) !void {
        try self.player.render(ctx);
    }
};
