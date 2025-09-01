const std = @import("std");
const Allocator = std.mem.Allocator;

const sdl = @import("sdl3");
const Surface = sdl.surface.Surface;
const Player = @import("../player.zig").Player;
const Map = @import("../map.zig").Map;
const Spritesheet = @import("../spritesheet.zig").Spritesheet;

pub const Level1 = struct {
    pub const Self = @This();

    var floor_tiles_image: Surface = undefined;
    var wall_tiles_image: Surface = undefined;

    alloc: Allocator,

    player: Player,
    map: Map(144, 144),

    pub fn init(alloc: Allocator) !Level1 {
        floor_tiles_image = try sdl.image.loadFile("./assets/images/floor_tiles.png");
        wall_tiles_image = try sdl.image.loadFile("./assets/images/wall_tiles.png");

        const floor_sheet = try Spritesheet.init(alloc, floor_tiles_image, 2, 3);
        const wall_sheet = try Spritesheet.init(alloc, wall_tiles_image, 3, 5);

        return .{
            .alloc = alloc,
            .player = try Player.init(alloc),
            .map = try .init(alloc, floor_sheet, wall_sheet, 16, 47.0, 10),
        };
    }

    pub fn deinit(self: *Self) void {
        self.player.deinit();
        self.map.deinit();
        floor_tiles_image.deinit();
        wall_tiles_image.deinit();
    }

    pub fn update(self: *Self, dt: f32) !void {
        try self.player.update(dt);
    }

    pub fn render(self: *Self, ctx: sdl.surface.Surface) !void {
        try self.map.render(ctx, 0, 0);
        try self.player.render(ctx);
    }
};
