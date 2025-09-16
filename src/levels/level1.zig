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
const Array2D = @import("../array_2d.zig").Array2D;

const Color = @import("../color.zig").Color;
const collides = @import("../math/sat.zig").collides;

const Game = @import("../game.zig");
const Input = @import("../input.zig");
const Entity = @import("../entity.zig").Entity;
const Player = @import("../player.zig").Player;
const Spritesheet = @import("../spritesheet.zig").Spritesheet;
const CollisionShape = @import("../math/collisionshape.zig").CollisionShape;
const rand = @import("../random.zig").rand;

const Bullet = @import("../projectiles/bullet.zig").Bullet;

const TileData = @import("../map.zig").TileData;

const map_size: UVector = .init(120, 77);

const Map = @import("../map.zig").Map(map_size.x, map_size.y, Game.tile_size);

const spatial_partition_factor: i32 = 4;
const Partition = @import("../math/spatial_partition.zig").SpatialPartition(
    *Entity,
    @divFloor(map_size.x, spatial_partition_factor) + 1,
    @divFloor(map_size.y, spatial_partition_factor) + 1,
);

pub const Level1 = struct {
    pub const Self = @This();

    var floor_tiles_image: Texture = undefined;
    var wall_tiles_image: Texture = undefined;

    map: Map,
    spatial_partition: Partition,
    player: *Player,
    bullets: std.ArrayList(*Bullet) = .empty,

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
            .map = .init(floor_sheet, wall_sheet, 47.0, 2),
            .spatial_partition = .init(),
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
        {
            var iter = Map.CollisionIterator(Player).init(&self.map, self.player, Player.collision_shape, dt);
            while (iter.next()) |result| {
                // NOTE: Currently only collides with wall/corner tiles.
                var mtv = result.getMinTranslationVector();
                if (result.collision_owner_a) mtv = mtv.negate();
                self.player.loc = self.player.loc.add(mtv);
                break;
            }
        }

        Game.camera.centerOnPoint(self.player.loc.add(self.player.sprite_offset));

        if (Input.getButtonState(.left) == .just_pressed) {
            self.raycast_hit_data = null;

            const player_center = self.player.loc.add(self.player.sprite_offset);

            const clicked_loc = Game.camera.screenToWorld(Input.mouse.loc);
            const raycast_end_loc = player_center.add(
                clicked_loc.subtract(player_center).normalize().scale(
                    Map.tile_diagonal_len * @max(map_size.x, map_size.y),
                ),
            );
            var raycast_iter = self.map.raycast(player_center, raycast_end_loc);
            while (raycast_iter.next()) |data| {
                if (data.tile.kind == .wall or data.tile.kind == .corner) {
                    self.raycast_hit_data = data;
                    break;
                }
            }

            // Shoot a bullet
            const bullet = Bullet.init(
                player_center,
                clicked_loc.subtract(player_center).normalize().scale(300.0),
            );
            self.bullets.append(Game.alloc, bullet) catch unreachable;
        }

        var bullets_to_delete = std.ArrayList(usize).empty;
        defer bullets_to_delete.deinit(Game.alloc);

        for (self.bullets.items, 0..) |bullet, i| {
            var iter = Map.CollisionIterator(Bullet).init(&self.map, bullet, Bullet.collision_shape, dt);
            while (iter.next()) |_| {
                // NOTE: Currently only collides with wall/corner tiles.
                bullets_to_delete.append(Game.alloc, i) catch unreachable;
                break;
            }
        }

        self.bullets.orderedRemoveMany(bullets_to_delete.items);
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

        for (self.bullets.items) |bullet| {
            bullet.render();
        }
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
