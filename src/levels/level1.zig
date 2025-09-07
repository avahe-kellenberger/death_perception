const std = @import("std");
const Allocator = std.mem.Allocator;

const sdl = @import("sdl3");
const Renderer = sdl.render.Renderer;
const Texture = sdl.render.Texture;
const vector_mod = @import("../math/vector.zig");
const Vector = vector_mod.Vector(f32);
const vector = vector_mod.vector;
const FRect = sdl.rect.FRect;

const collides = @import("../math/sat.zig").collides;

const Game = @import("../game.zig");
const Input = @import("../input.zig");
const Player = @import("../player.zig").Player;
const Spritesheet = @import("../spritesheet.zig").Spritesheet;
const CollisionShape = @import("../math/collisionshape.zig").CollisionShape;

const TileData = @import("../map.zig").TileData;

const Map = @import("../map.zig").Map(144, 144, 16.0);

const GREEN: sdl.pixels.Color = .{ .r = 0, .g = 255, .b = 0, .a = 100 };
const RED: sdl.pixels.Color = .{ .r = 255, .g = 0, .b = 0, .a = 100 };
const BLUE: sdl.pixels.Color = .{ .r = 0, .g = 0, .b = 255, .a = 100 };

pub const Level1 = struct {
    pub const Self = @This();

    var floor_tiles_image: Texture = undefined;
    var wall_tiles_image: Texture = undefined;

    alloc: Allocator,

    player: Player,
    map: Map,

    // NOTE: Testing code below, can remove later
    raycast_start_loc: ?Vector = null,
    raycast_end_loc: ?Vector = null,
    raycast_tiles: ?[]TileData = null,

    pub fn init(alloc: Allocator) Level1 {
        // Map floor color so we can ignore drawing "empty" tiles
        Game.bg_color = .{ .r = 139, .g = 155, .b = 180, .a = 255 };

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
            .map = .init(alloc, floor_sheet, wall_sheet, 47.0, 10),
        };
    }

    pub fn deinit(self: *Self) void {
        self.player.deinit();
        self.map.deinit();
        floor_tiles_image.deinit();
        wall_tiles_image.deinit();
    }

    pub fn update(self: *Self, dt: f32) void {
        const start_loc = self.player.loc;
        self.player.update(dt);

        const tile_shape: CollisionShape = self.map.collision_shape;

        const min_x: usize = @intFromFloat(@floor((@min(start_loc.x, self.player.loc.x) - Player.collision_shape.Circle.radius) / Map.tile_size));
        const max_x: usize = @intFromFloat(@ceil((@max(start_loc.x, self.player.loc.x) + Player.collision_shape.Circle.radius) / Map.tile_size));

        const min_y: usize = @intFromFloat(@floor((@min(start_loc.y, self.player.loc.y) - Player.collision_shape.Circle.radius) / Map.tile_size));
        const max_y: usize = @intFromFloat(@ceil((@max(start_loc.y, self.player.loc.y) + Player.collision_shape.Circle.radius) / Map.tile_size));

        var iter = self.map.tiles.window(.{
            .x = min_x,
            .y = min_y,
            .w = max_x - min_x + 1,
            .h = max_y - min_y + 1,
        });

        while (iter.next()) |t| {
            if (!t.t.is_wall) continue;

            const tile_loc = vector(
                @as(f32, @floatFromInt(t.x)) * Map.tile_size,
                @as(f32, @floatFromInt(t.y)) * Map.tile_size,
            );

            if (collides(
                self.alloc,
                self.player.loc,
                Player.collision_shape,
                self.player.loc.subtract(start_loc),
                tile_loc,
                tile_shape,
                Vector.Zero,
            )) |result| {
                if (result.collision_owner_a) {
                    self.player.loc = self.player.loc.add(result.invert().getMinTranslationVector());
                } else {
                    self.player.loc = self.player.loc.add(result.getMinTranslationVector());
                }
            }
        }

        Game.camera.centerOnPoint(self.player.loc);
    }

    pub fn render(self: *Self) void {
        self.map.render();

        if (Input.getButtonState(.left) == .just_pressed) {
            self.raycast_start_loc = Game.camera.screenToWorld(Input.mouse.loc);
            if (self.raycast_tiles) |t| {
                self.alloc.free(t);
                self.raycast_tiles = null;
            }
        } else if (self.raycast_start_loc) |start| if (Input.getButtonState(.right) == .just_pressed) {
            const end = Game.camera.screenToWorld(Input.mouse.loc);
            self.raycast_end_loc = end;

            if (self.raycast_tiles) |t| {
                self.alloc.free(t);
                self.raycast_tiles = null;
            }

            self.raycast_tiles = self.map.raycast(start, end);
            std.log.err("Raycast found {} tiles", .{self.raycast_tiles.?.len});
        };

        // NOTE: Allows for transparency (should this just be our default?)
        Game.setBlendMode(.blend);

        if (self.raycast_start_loc) |start| {
            Game.fillRect(.{ .x = start.x - 1, .y = start.y - 1, .w = 2, .h = 2 }, GREEN);
        }

        if (self.raycast_end_loc) |end| {
            Game.fillRect(.{ .x = end.x - 1, .y = end.y - 1, .w = 2, .h = 2 }, RED);
        }

        if (self.raycast_tiles) |tiles| for (tiles) |t| {
            const rect: FRect = .{
                .x = @as(f32, @floatFromInt(t.x)) * 16.0,
                .y = @as(f32, @floatFromInt(t.y)) * 16.0,
                .w = Map.tile_size,
                .h = Map.tile_size,
            };
            Game.fillRect(rect, BLUE);
        };

        if (self.raycast_start_loc) |start| if (self.raycast_end_loc) |end| {
            Game.renderer.setDrawColor(RED) catch unreachable;
            Game.renderer.renderLine(
                .{ .x = start.x - Game.camera.viewport.x, .y = start.y - Game.camera.viewport.y },
                .{ .x = end.x - Game.camera.viewport.x, .y = end.y - Game.camera.viewport.y },
            ) catch unreachable;
        };

        Game.resetBlendMode();

        self.player.render();
    }

    fn getHoveredTileBounds() FRect {
        const mouse_world_coord: Vector = Game.camera.screenToWorld(Input.mouse.loc);
        return .{
            .x = @floor(mouse_world_coord.x / Map.tile_size) * Map.tile_size,
            .y = @floor(mouse_world_coord.y / Map.tile_size) * Map.tile_size,
            .w = Map.tile_size,
            .h = Map.tile_size,
        };
    }
};
