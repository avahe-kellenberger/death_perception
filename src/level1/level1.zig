const std = @import("std");
const Allocator = std.mem.Allocator;

const sdl = @import("sdl3");
const Renderer = sdl.render.Renderer;
const Texture = sdl.render.Texture;
const Player = @import("../player.zig").Player;
const Map = @import("../map.zig").Map;
const Spritesheet = @import("../spritesheet.zig").Spritesheet;

pub const Level1 = struct {
    pub const Self = @This();

    var floor_tiles_image: Texture = undefined;
    var wall_tiles_image: Texture = undefined;

    alloc: Allocator,

    player: Player,
    map: Map(144, 144),

    pub fn init(alloc: Allocator, renderer: Renderer) !Level1 {
        floor_tiles_image = try sdl.image.loadTexture(renderer, "./assets/images/floor_tiles.png");
        try floor_tiles_image.setScaleMode(.nearest);

        wall_tiles_image = try sdl.image.loadTexture(renderer, "./assets/images/wall_tiles.png");
        try wall_tiles_image.setScaleMode(.nearest);

        const floor_sheet = try Spritesheet.init(alloc, floor_tiles_image, 2, 3);
        const wall_sheet = try Spritesheet.init(alloc, wall_tiles_image, 3, 5);

        return .{
            .alloc = alloc,
            .player = try Player.init(alloc, renderer),
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

    pub fn render(self: *Self, ctx: Renderer) !void {
        try self.map.render(ctx, 0, 0);
        try self.player.render(ctx, 0, 0);
    }
};
