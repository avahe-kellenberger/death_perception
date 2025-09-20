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
const EntityList = @import("../entity.zig").EntityList;
const Player = @import("../player.zig").Player;
const Spritesheet = @import("../spritesheet.zig").Spritesheet;
const CollisionShape = @import("../math/collisionshape.zig").CollisionShape;
const rand = @import("../random.zig").rand;

const occlusion = @import("../occlusion.zig");

const Bullet = @import("../projectiles/bullet.zig").Bullet;

const TileData = @import("../map.zig").TileData;

const map_size: UVector = .init(120, 77);
const Map = @import("../map.zig").Map(map_size.x, map_size.y, Game.tile_size);

const spatial_partition_factor: i32 = 4;
const Partition = @import("../math/spatial_partition.zig").SpatialPartition(
    Entity,
    @divFloor(map_size.x, spatial_partition_factor) + 1,
    @divFloor(map_size.y, spatial_partition_factor) + 1,
);
const WallsPartition = @import("../math/spatial_partition.zig").SpatialPartition(
    CollisionShape,
    @divFloor(map_size.x, spatial_partition_factor) + 1,
    @divFloor(map_size.y, spatial_partition_factor) + 1,
);

pub const Level1 = struct {
    pub const Self = @This();

    var floor_tiles_image: Texture = undefined;
    var wall_tiles_image: Texture = undefined;

    entities: EntityList,
    player_id: u32 = 0,

    map: Map,
    spatial_partition: Partition,
    walls_spatial_partition: WallsPartition,
    // player: Player,
    bullets: std.ArrayList(*Bullet) = .empty,

    // NOTE: Testing code below, can remove later
    raycast_hit_data: ?TileData = null,

    occlusion_texture: Texture,

    pub fn init() Level1 {
        // Map floor color so we can ignore drawing "empty" tiles
        Game.bg_color = .{ .r = 139, .g = 155, .b = 180, .a = 255 };
        Game.camera.zoom(0.7);

        floor_tiles_image = Game.loadTexture("./assets/images/floor_tiles.png", .nearest);
        wall_tiles_image = Game.loadTexture("./assets/images/wall_tiles.png", .nearest);

        const floor_sheet = Spritesheet.init(floor_tiles_image, 2, 3);
        const wall_sheet = Spritesheet.init(wall_tiles_image, 3, 5);

        const target_size = Game.renderer.getOutputSize() catch unreachable;

        // for (result.map.determineLines()) |*line| {
        //     result.walls_spatial_partition.insert(0, 0, line);
        // }

        var map: Map = .init(floor_sheet, wall_sheet, 47.0, 2);

        // Make sure the players spawns on the ground.
        var player: Player = .init();
        while (true) {
            const tile_loc: UVector = .init(rand(usize, 0, map_size.x - 1), rand(usize, 0, map_size.y - 1));
            if (map.tiles.get(tile_loc.x, tile_loc.y).kind == .floor) {
                player.loc = .init(
                    Map.tile_size * @as(f32, @floatFromInt(tile_loc.x)),
                    Map.tile_size * @as(f32, @floatFromInt(tile_loc.y)),
                );
                break;
            }
        }
        var entities: EntityList = .init();
        const player_id = entities.add(.{ .player = player });
        return .{
            .entities = entities,
            .player_id = player_id,
            .map = map,
            .spatial_partition = .init(),
            .walls_spatial_partition = .init(),
            .occlusion_texture = sdl.render.Texture.initWithProperties(Game.renderer, .{
                .width = target_size.width,
                .height = target_size.height,
                .access = .target,
                .format = .{ .value = .packed_rgba_8_8_8_8 },
            }) catch unreachable,
        };
    }

    pub fn deinit(self: *Self) void {
        self.entities.remove(self.player_id);
        // self.player.deinit();
        self.map.deinit();
        floor_tiles_image.deinit();
        wall_tiles_image.deinit();
    }

    pub fn update(self: *Self, dt: f32) void {
        var player = self.entities.getAs(.player, self.player_id).?;
        {
            var iter = Map.CollisionIterator(Player).init(&self.map, player, Player.collision_shape, dt);
            while (iter.next()) |result| {
                // NOTE: Currently only collides with wall/corner tiles.
                var mtv = result.getMinTranslationVector();
                if (result.collision_owner_a) mtv = mtv.negate();
                player.loc = player.loc.add(mtv);
                break;
            }
        }

        Game.camera.centerOnPoint(player.loc.add(player.sprite_offset));

        if (Input.getButtonState(.left) == .just_pressed) {
            self.raycast_hit_data = null;

            const player_center = player.loc.add(player.sprite_offset);

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
        self.map.renderFloor();

        var player = self.entities.getAs(.player, self.player_id).?;
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
        player.render();

        for (self.bullets.items) |bullet| {
            bullet.render();
        }

        var mesh = occlusion.VisibilityMesh.init(player.loc, self.map.lines.items);
        defer mesh.deinit();
        mesh.renderTo(self.occlusion_texture);
        Game.renderer.renderTexture(self.occlusion_texture, null, null) catch unreachable;

        self.map.renderWalls();
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
