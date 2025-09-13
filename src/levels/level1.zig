const std = @import("std");
const Allocator = std.mem.Allocator;

const sdl = @import("sdl3");
const Renderer = sdl.render.Renderer;
const Texture = sdl.render.Texture;
const vector_mod = @import("../math/vector.zig");
const Vector = vector_mod.Vector(f32);
const vector = vector_mod.vector;
const FRect = sdl.rect.FRect;

const Color = @import("../color.zig").Color;
const collides = @import("../math/sat.zig").collides;

const Game = @import("../game.zig");
const Input = @import("../input.zig");
const Player = @import("../player.zig").Player;
const Spritesheet = @import("../spritesheet.zig").Spritesheet;
const CollisionShape = @import("../math/collisionshape.zig").CollisionShape;

const TileData = @import("../map.zig").TileData;

const Map = @import("../map.zig").Map(144, 144, Game.tile_size);

pub const Level1 = struct {
    pub const Self = @This();

    var floor_tiles_image: Texture = undefined;
    var wall_tiles_image: Texture = undefined;

    player: *Player,
    map: Map,

    // NOTE: Testing code below, can remove later
    raycast_start_loc: ?Vector = null,
    raycast_end_loc: ?Vector = null,

    pub fn init() Level1 {
        // Map floor color so we can ignore drawing "empty" tiles
        Game.bg_color = .{ .r = 139, .g = 155, .b = 180, .a = 255 };

        floor_tiles_image = Game.loadTexture("./assets/images/floor_tiles.png", .nearest);
        wall_tiles_image = Game.loadTexture("./assets/images/wall_tiles.png", .nearest);

        const floor_sheet = Spritesheet.init(floor_tiles_image, 2, 3);
        const wall_sheet = Spritesheet.init(wall_tiles_image, 3, 5);

        var player = Player.init();
        player.loc.x = Map.tile_size * 70;
        player.loc.y = Map.tile_size * 70;

        return .{
            .player = player,
            .map = .init(floor_sheet, wall_sheet, 47.0, 10),
        };
    }

    pub fn deinit(self: *Self) void {
        self.player.deinit();
        self.map.deinit();
        floor_tiles_image.deinit();
        wall_tiles_image.deinit();
        Game.alloc.destroy(self.player);
    }

    pub fn update(self: *Self, dt: f32) void {
        const start_loc = self.player.loc;
        self.player.update(dt);

        const tile_shape: CollisionShape = self.map.collision_shape;

        const movement_area = Map.getPotentialArea(
            &Player.collision_shape,
            self.player.loc,
            self.player.loc.subtract(start_loc),
        );
        var iter = self.map.tiles.window(movement_area);

        while (iter.next()) |t| {
            if (!t.t.is_wall) continue;

            const tile_loc = vector(
                @as(f32, @floatFromInt(t.x)) * Map.tile_size,
                @as(f32, @floatFromInt(t.y)) * Map.tile_size,
            );

            const player_loc = self.player.loc;
            if (collides(
                Game.alloc,
                player_loc,
                Player.collision_shape,
                player_loc.subtract(start_loc),
                tile_loc,
                tile_shape,
                Vector.zero,
            )) |result| {
                if (result.collision_owner_a) {
                    self.player.loc = player_loc.add(result.invert().getMinTranslationVector().scale(0.5));
                } else {
                    self.player.loc = player_loc.add(result.getMinTranslationVector().scale(0.5));
                }
            }
        }

        Game.camera.centerOnPoint(self.player.loc.add(self.player.sprite_offset));

        if (Input.getButtonState(.left) == .just_pressed) {
            self.raycast_start_loc = Game.camera.screenToWorld(Input.mouse.loc).round();
        } else if (Input.getButtonState(.right) == .just_pressed) {
            self.raycast_end_loc = Game.camera.screenToWorld(Input.mouse.loc).round();
        }
    }

    pub fn render(self: *Self) void {
        self.map.render();

        if (self.raycast_start_loc) |start| if (self.raycast_end_loc) |end| {
            var iter = self.map.raycast(start, end);
            while (iter.next()) |t| {
                const rect: FRect = .{
                    .x = @as(f32, @floatFromInt(t.x)) * Map.tile_size,
                    .y = @as(f32, @floatFromInt(t.y)) * Map.tile_size,
                    .w = Map.tile_size,
                    .h = Map.tile_size,
                };
                Game.fillRect(rect, Color.blue.sdl());
            }
        };

        if (self.raycast_start_loc) |start| if (self.raycast_end_loc) |end| {
            Game.renderer.setDrawColor(Color.black.sdl()) catch unreachable;
            Game.renderer.renderLine(
                .{ .x = start.x - Game.camera.viewport.x, .y = start.y - Game.camera.viewport.y },
                .{ .x = end.x - Game.camera.viewport.x, .y = end.y - Game.camera.viewport.y },
            ) catch unreachable;
        };

        if (self.raycast_start_loc) |start| {
            Game.fillRect(.{ .x = start.x, .y = start.y, .w = 1, .h = 1 }, Color.green.sdl());
        }

        if (self.raycast_end_loc) |end| {
            Game.fillRect(.{ .x = end.x, .y = end.y, .w = 1, .h = 1 }, Color.red.sdl());
        }

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
