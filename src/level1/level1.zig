const std = @import("std");
const Allocator = std.mem.Allocator;

const sdl = @import("sdl3");
const Renderer = sdl.render.Renderer;
const Texture = sdl.render.Texture;
const FPoint = sdl.rect.FPoint;

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
    camera: *Camera,

    pub fn init(alloc: Allocator, renderer: Renderer, camera: *Camera) !Level1 {
        floor_tiles_image = try sdl.image.loadTexture(renderer, "./assets/images/floor_tiles.png");
        try floor_tiles_image.setScaleMode(.nearest);

        wall_tiles_image = try sdl.image.loadTexture(renderer, "./assets/images/wall_tiles.png");
        try wall_tiles_image.setScaleMode(.nearest);

        const floor_sheet = try Spritesheet.init(alloc, floor_tiles_image, 2, 3);
        const wall_sheet = try Spritesheet.init(alloc, wall_tiles_image, 3, 5);

        var player = try Player.init(alloc, renderer);
        player.loc.x = 16 * 70;
        player.loc.y = 16 * 70;

        return .{
            .alloc = alloc,
            .camera = camera,
            .player = player,
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
        self.camera.centerOnPoint(self.player.loc);
    }

    pub fn render(self: *Self, ctx: Renderer) !void {
        const relative_z = 1.0 - self.camera.getZoom();
        if (relative_z <= 0) return;

        const inversedScalar = 1.0 / relative_z;
        const offset: FPoint = .{
            .x = -1 * (self.camera.loc.x - self.camera.half_viewport_size.w * relative_z),
            .y = -1 * (self.camera.loc.y - self.camera.half_viewport_size.h * relative_z),
        };

        try ctx.setScale(inversedScalar, inversedScalar);

        try self.map.render(ctx, self.camera, offset);
        try self.player.render(ctx, self.camera, offset);

        try ctx.setScale(relative_z, relative_z);
    }
};
