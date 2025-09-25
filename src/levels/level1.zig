const std = @import("std");
const builtin = @import("builtin");
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

pub const Level1 = struct {
    pub const Self = @This();

    var floor_tiles_image: Texture = undefined;
    var wall_tiles_image: Texture = undefined;

    entities: EntityList,
    entities_to_remove: std.ArrayList(u32) = .empty,

    player_id: u32 = 0,

    map: Map,

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
        const player_id = entities.add(player);
        return .{
            .entities = entities,
            .player_id = player_id,
            .map = map,
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
        self.entities.deinit();
        self.entities_to_remove.deinit(Game.alloc);
        self.map.deinit();
        floor_tiles_image.deinit();
        wall_tiles_image.deinit();
    }

    pub fn update(self: *Self, dt: f32) void {
        var entity_iter = self.entities.entities.iterator();
        while (entity_iter.next()) |kv| switch (kv.value_ptr.*) {
            .player => |*player| {
                player.update(dt);
                var iter = Map.CollisionIterator(Player).init(&self.map, player, player.velocity.scale(dt));
                var mtv: Vector = Vector.zero;
                var i: u8 = 0;
                while (iter.next()) |result| {
                    var tmp = result.getMinTranslationVector();
                    if (result.collision_owner_a) tmp = tmp.negate();
                    mtv = mtv.merge(tmp);
                    i += 1;
                    if (i >= 100) break;
                }
                if (i >= 100) {
                    std.log.err("Excessive collisions", .{});
                    if (builtin.mode == .Debug) {
                        std.process.exit(1);
                    }
                }

                player.loc = player.loc.add(player.velocity.scale(dt)).add(mtv);
                Game.camera.centerOnPoint(player.loc.add(player.sprite_offset));
            },
            .bullet => |*bullet| {
                bullet.update(dt);
                var iter = Map.CollisionIterator(Bullet).init(&self.map, bullet, bullet.velocity.scale(dt));
                if (iter.next()) |_| {
                    self.entities_to_remove.append(Game.alloc, kv.key_ptr.*) catch unreachable;
                }
            },
        };

        while (self.entities_to_remove.pop()) |id| {
            self.entities.remove(id);
        }

        if (Input.getButtonState(.left) == .just_pressed) {
            self.raycast_hit_data = null;

            const player: *Player = self.entities.getAs(.player, self.player_id) orelse unreachable;
            const player_center = player.loc.add(player.sprite_offset.scale(0.5));

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
            _ = self.entities.add(bullet);
        }
    }

    pub fn render(self: *Self) void {
        self.map.renderFloor();

        const player = self.entities.getAs(.player, self.player_id).?;
        if (self.raycast_hit_data) |data| {
            Game.setRenderColor(.{ .r = 255, .a = 80 });
            Game.fillRect(
                .{
                    .x = @as(f32, @floatFromInt(data.tile_x)) * Map.tile_size,
                    .y = @as(f32, @floatFromInt(data.tile_y)) * Map.tile_size,
                    .w = Map.tile_size,
                    .h = Map.tile_size,
                },
            );
            Game.setRenderColor(Color.green);
            Game.fillRect(.{ .x = data.x, .y = data.y, .w = 1, .h = 1 });
        }

        {
            var iter = self.entities.entities.iterator();
            while (iter.next()) |kv| switch (kv.value_ptr.*) {
                inline else => |*entity| entity.render(),
            };
        }

        var mesh = occlusion.VisibilityMesh.init(player.loc, self.map.walls.items);
        defer mesh.deinit();
        mesh.renderTo(self.occlusion_texture);
        Game.renderer.renderTexture(self.occlusion_texture, null, null) catch unreachable;

        self.map.renderWalls();

        const area = @TypeOf(self.map.walls_spatial_partition).getPotentialArea(
            Player.collision_shape,
            player.loc,
            player.velocity.scale(1 / 165),
        );
        Game.renderer.setDrawBlendMode(.blend) catch unreachable;
        Game.setRenderColor(Color.red.with(.{ .a = 25 }));
        Game.fillRect(.{
            .x = @as(f32, @floatFromInt(area.x * 10)) * 16.0,
            .y = @as(f32, @floatFromInt(area.y * 10)) * 16.0,
            .w = @as(f32, @floatFromInt(area.w * 10)) * 16.0,
            .h = @as(f32, @floatFromInt(area.h * 10)) * 16.0,
        });

        Game.setRenderColor(.red);
        Player.collision_shape.render(player.loc);
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
