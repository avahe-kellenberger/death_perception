const std = @import("std");
const Allocator = std.mem.Allocator;

const sdl = @import("sdl3");
const Player = @import("../player.zig").Player;
const Map = @import("../map.zig").Map;

pub const Level1 = struct {
    pub const Self = @This();

    alloc: Allocator,

    player: Player,
    map: Map(100, 100),

    pub fn init(alloc: Allocator) !Level1 {
        return .{
            .alloc = alloc,
            .player = try Player.init(alloc),
            .map = try Map(100, 100).init(alloc, 32, 46.0, 4),
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
