const std = @import("std");
const Allocator = std.mem.Allocator;

const sdl = @import("sdl3");
const Renderer = sdl.render.Renderer;
const Texture = sdl.render.Texture;
const FPoint = sdl.rect.FPoint;

const Game = @import("../game.zig");
const Player = @import("../player.zig").Player;
const Map = @import("../map.zig").Map;
const Spritesheet = @import("../spritesheet.zig").Spritesheet;
const Camera = @import("../camera.zig").Camera;

pub const Level1 = struct {
    pub const Self = @This();

    var floor_tiles_image: Texture = undefined;
    var wall_tiles_image: Texture = undefined;

    alloc: Allocator,

    player: Player,
    map: Map(144, 144),

    pub fn init(alloc: Allocator) Level1 {
        floor_tiles_image = Game.loadTexture("./assets/images/floor_tiles.png", .nearest);
        wall_tiles_image = Game.loadTexture("./assets/images/wall_tiles.png", .nearest);

        const floor_sheet = Spritesheet.init(alloc, floor_tiles_image, 2, 3);
        const wall_sheet = Spritesheet.init(alloc, wall_tiles_image, 3, 5);

        var player = Player.init();
        player.loc.x = 16 * 70;
        player.loc.y = 16 * 70;

        return .{
            .alloc = alloc,
            .player = player,
            .map = .init(alloc, floor_sheet, wall_sheet, 16, 47.0, 10),
        };
    }

    pub fn deinit(self: *Self) void {
        self.player.deinit();
        self.map.deinit();
        floor_tiles_image.deinit();
        wall_tiles_image.deinit();
    }

    pub fn update(self: *Self, dt: f32) void {
        self.player.update(dt);
        Game.camera.centerOnPoint(self.player.loc);
    }

    pub fn render(self: *Self) void {
        self.map.render();
        self.player.render();
    }
};
