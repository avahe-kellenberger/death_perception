const std = @import("std");
const Allocator = std.mem.Allocator;

const sdl = @import("sdl3");
const Renderer = sdl.render.Renderer;
const Texture = sdl.render.Texture;
const vector_mod = @import("../math/vector.zig");
const Vector = vector_mod.Vector(f32);
const UVector = vector_mod.Vector(usize);
const vector = vector_mod.vector;
const FRect = sdl.rect.FRect;

const Color = @import("../color.zig").Color;
const collides = @import("../math/sat.zig").collides;

const Game = @import("../game.zig");
const Input = @import("../input.zig");
const Player = @import("../player.zig").Player;
const Spritesheet = @import("../spritesheet.zig").Spritesheet;
const CollisionShape = @import("../math/collisionshape.zig").CollisionShape;
const rand = @import("../random.zig").rand;

const TileData = @import("../map.zig").TileData;

const map_size: UVector = .init(144, 144);

const Map = @import("../map.zig").Map(map_size.x, map_size.y, Game.tile_size);

pub const Level1 = struct {
    pub const Self = @This();

    var floor_tiles_image: Texture = undefined;
    var wall_tiles_image: Texture = undefined;

    player: *Player,
    map: Map,

    // NOTE: Testing code below, can remove later
    raycast_hit_data: ?TileData = null,

    pub fn init() Level1 {
        // Map floor color so we can ignore drawing "empty" tiles
        Game.bg_color = .{ .r = 139, .g = 155, .b = 180, .a = 255 };
        Game.camera.zoom(0.7);

        floor_tiles_image = Game.loadTexture("./assets/images/floor_tiles.png", .nearest);
        wall_tiles_image = Game.loadTexture("./assets/images/wall_tiles.png", .nearest);

        const floor_sheet = Spritesheet.init(floor_tiles_image, 2, 3);
        const wall_sheet = Spritesheet.init(wall_tiles_image, 3, 5);

        var player = Player.init();

        const result: Level1 = .{
            .player = player,
            .map = .init(floor_sheet, wall_sheet, 47.0, 10),
        };

        // Make sure the players spawns on the ground.
        while (true) {
            const tile_loc: UVector = .init(rand(usize, 0, map_size.x - 1), rand(usize, 0, map_size.y - 1));
            if (result.map.tiles.get(tile_loc.x, tile_loc.y).kind == .floor) {
                player.loc = .init(
                    Map.tile_size * @as(f32, @floatFromInt(tile_loc.x)),
                    Map.tile_size * @as(f32, @floatFromInt(tile_loc.y)),
                );
                break;
            }
        }

        return result;
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
            if (t.t.kind != .wall and t.t.kind != .corner) continue;

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
                var mtv = result.getMinTranslationVector();
                if (result.collision_owner_a) mtv = mtv.negate();
                self.player.loc = player_loc.add(mtv);
            }
        }

        Game.camera.centerOnPoint(self.player.loc.add(self.player.sprite_offset));

        if (Input.getButtonState(.left) == .just_pressed) {
            self.raycast_hit_data = null;

            const raycast_start_loc = self.player.loc.round();
            const clicked_loc = Game.camera.screenToWorld(Input.mouse.loc);
            const raycast_end_loc = raycast_start_loc.add(
                clicked_loc.subtract(raycast_start_loc).normalize().scale(
                    Map.tile_diagonal_len * @max(map_size.x, map_size.y),
                ),
            );
            var raycast_iter = self.map.raycast(raycast_start_loc, raycast_end_loc);
            while (raycast_iter.next()) |data| {
                if (data.tile.kind == .wall or data.tile.kind == .corner) {
                    self.raycast_hit_data = data;
                    break;
                }
            }
        }
    }

    pub fn render(self: *Self) void {
        self.map.render();

        if (self.raycast_hit_data) |data| {
            Game.fillRect(
                .{
                    .x = @as(f32, @floatFromInt(data.tile_x)) * Map.tile_size,
                    .y = @as(f32, @floatFromInt(data.tile_y)) * Map.tile_size,
                    .w = Map.tile_size,
                    .h = Map.tile_size,
                },
                .{ .r = 255, .a = 80 },
            );
            Game.fillRect(.{ .x = data.x, .y = data.y, .w = 1, .h = 1 }, Color.green);
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
