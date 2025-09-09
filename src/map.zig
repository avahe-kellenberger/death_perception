const std = @import("std");
const builtin = @import("builtin");
const Allocator = std.mem.Allocator;

const sdl = @import("sdl3");
const Renderer = sdl.render.Renderer;
const FRect = sdl.rect.FRect;
const IPoint = sdl.rect.IPoint;

const Game = @import("game.zig");
const rand = @import("random.zig").rand;
const Array2D = @import("array_2d.zig").Array2D;
const ArrayWindow = @import("array_2d.zig").ArrayWindow;
const Spritesheet = @import("spritesheet.zig").Spritesheet;

const vector_mod = @import("math/vector.zig");
const Vector = vector_mod.Vector(f32);
const vector = vector_mod.vector;

const CollisionShape = @import("math/collisionshape.zig").CollisionShape;

pub const Tile = struct {
    floor_image_index: isize = -1,
    wall_image_index: isize = -1,
    neighbor_bit_sum: u8 = 0,
    is_wall: bool = false,
};

pub const TileData = struct {
    tile: *Tile,
    x: usize,
    y: usize,
};

pub fn Map(comptime width: usize, comptime height: usize, _tile_size: f32) type {
    return struct {
        pub const Self = @This();
        pub const tile_size: f32 = _tile_size;

        alloc: Allocator,
        floor_tiles_sheet: Spritesheet,
        wall_tiles_sheet: Spritesheet,
        tiles: *Array2D(Tile, width, height),

        collision_shape: CollisionShape,

        pub fn init(
            alloc: Allocator,
            floor_tiles_sheet: Spritesheet,
            wall_tiles_sheet: Spritesheet,
            density: f32,
            border_thickness: usize,
        ) Map(width, height, _tile_size) {
            var tiles = alloc.create(Array2D(Tile, width, height)) catch unreachable;
            tiles.setAllValues(Tile{});

            var result = Map(width, height, _tile_size){
                .alloc = alloc,
                .floor_tiles_sheet = floor_tiles_sheet,
                .wall_tiles_sheet = wall_tiles_sheet,
                .tiles = tiles,
                .collision_shape = .{ .aabb = .init(vector(0, 0), vector(_tile_size, _tile_size)) },
            };

            var iter = result.tiles.iterator();
            while (iter.next()) |e| {
                // Initialize all tiles
                e.t.* = .{
                    .is_wall = (e.x < border_thickness or
                        e.x >= (width - border_thickness) or
                        e.y < border_thickness or
                        e.y >= (height - border_thickness) or
                        (density > 0 and density >= rand(f32, 0, 100))),
                };
            }

            // Create basic map layout
            processCellularAutoma(&result);
            // Eliminate any smaller secluded rooms that were generated
            fillSmallerRooms(&result) catch unreachable;
            // Select correct images after map has been generated
            setupTileImages(&result);
            return result;
        }

        pub fn deinit(self: *Self) void {
            self.floor_tiles_sheet.deinit();
            self.wall_tiles_sheet.deinit();
        }

        fn processCellularAutoma(self: *Self) void {
            const max_iterations = 100;
            var failed = true;

            for (0..max_iterations) |i| {
                var has_changed = false;
                var iter = self.tiles.iterator();
                while (iter.next()) |e| {
                    var num_neighboring_walls: usize = 0;
                    for (self.getMooreNeighborhood(e.x, e.y)) |is_wall| {
                        if (is_wall) num_neighboring_walls += 1;
                    }

                    if (self.tiles.get(e.x, e.y).is_wall) {
                        num_neighboring_walls += 1;
                    }

                    const was_wall = self.tiles.get(e.x, e.y).is_wall;
                    const is_wall = num_neighboring_walls > 4;

                    if (was_wall != is_wall) {
                        has_changed = true;
                        e.t.is_wall = is_wall;
                        e.t.floor_image_index = -1;
                        e.t.wall_image_index = -1;
                    }
                }

                // Nothing left to process.
                if (!has_changed) {
                    failed = false;
                    std.log.debug("Finished in {} iterations", .{i});
                    break;
                }
            }

            if (failed) @panic(std.fmt.comptimePrint(
                "Failed to process cellular automata for map in {} iterations!",
                .{max_iterations},
            ));
        }

        const Coordinate = struct { x: usize, y: usize };

        /// Eliminate any smaller secluded rooms that were generated
        fn fillSmallerRooms(self: *Self) !void {
            var visited = Array2D(bool, width, height).init(false);

            var rooms: std.ArrayList([]Coordinate) = .empty;
            defer {
                for (rooms.items) |room| self.alloc.free(room);
                rooms.deinit(self.alloc);
            }

            var iter = self.tiles.iterator();
            while (iter.next()) |e| {
                if (e.t.is_wall) continue;

                // Found a floor tile, skip if we've seen it before
                if (visited.get(e.x, e.y).*) continue;

                // New tile we haven't seen before!
                // Start flood fill for current room
                var room: std.ArrayList(Coordinate) = .empty;
                defer room.deinit(self.alloc);

                // Flood fill find all connected floor tiles
                var queue: std.ArrayList(Coordinate) = .empty;
                defer queue.deinit(self.alloc);

                try queue.append(self.alloc, .{ .x = e.x, .y = e.y });
                while (queue.pop()) |n| {
                    if (self.tiles.get(n.x, n.y).is_wall or visited.get(n.x, n.y).*) continue;
                    // Add tile to the current room
                    try room.append(self.alloc, n);
                    visited.set(n.x, n.y, true);

                    if (n.x > 0) try queue.append(self.alloc, .{
                        .x = n.x - 1,
                        .y = n.y,
                    });

                    if (n.x + 1 < width) try queue.append(self.alloc, .{
                        .x = n.x + 1,
                        .y = n.y,
                    });

                    if (n.y > 0) try queue.append(self.alloc, .{
                        .x = n.x,
                        .y = n.y - 1,
                    });

                    if (n.y + 1 < height) try queue.append(self.alloc, .{
                        .x = n.x,
                        .y = n.y + 1,
                    });
                }

                try rooms.append(self.alloc, try room.toOwnedSlice(self.alloc));
            }

            // Sort rooms by size in descending order
            std.mem.sort([]Coordinate, rooms.items, {}, compareRooms);

            // Fill every room except the largest
            for (rooms.items, 0..) |room, i| {
                if (i == 0) continue;
                for (room) |coord| {
                    var tile = self.tiles.get(coord.x, coord.y);
                    tile.is_wall = true;
                }
            }
        }

        fn compareRooms(_: void, a: []Coordinate, b: []Coordinate) bool {
            return a.len > b.len;
        }

        fn setupTileImages(self: *Self) void {
            var iter = self.tiles.iterator();
            while (iter.next()) |e| {
                e.t.neighbor_bit_sum = self.calcNeighborBitsum(e.t.is_wall, e.x, e.y);
                if (e.t.is_wall) {
                    e.t.wall_image_index = switch (e.t.neighbor_bit_sum) {
                        255 => 0,
                        107, 111, 235 => 1,
                        182, 183, 214, 215, 246 => 2,
                        180, 212, 240, 244 => 3,
                        248, 249, 252 => 4,
                        105, 216, 217, 232, 233 => 5,
                        22, 23, 54, 55, 150, 151 => 6,
                        31, 63, 159 => 7,
                        11, 15, 43, 47, 91, 95 => 8,
                        127 => 9,
                        191, 223 => 10,
                        251 => 11,
                        254 => 12,
                        219 => 14,
                        else => 0,
                    };

                    e.t.floor_image_index = switch (e.t.neighbor_bit_sum) {
                        212, 232, 240, 244, 248, 249, 252 => 0,
                        105, 233 => 3,
                        else => -1,
                    };
                } else {
                    e.t.floor_image_index = switch (e.t.neighbor_bit_sum) {
                        100, 104, 105, 232, 233, 248, 249, 252 => 2,
                        22, 150, 214, 246 => 3,
                        254 => 4,
                        208, 212, 240, 244 => 5,
                        // This is usually image index 0, but we don't need to draw the empty tile.
                        else => -1,
                    };
                }
            }
        }

        /// Calculates a bit sum based on all neighboring tiles:
        ///
        /// 0 1 0
        /// 0 X 1
        /// 1 0 0
        ///
        /// Where X is the local tile, and each 0 or 1 representing a neighboring tile.
        /// 8 neighboring tiles = 8 bits of info, with a 1 representing a wall.
        ///
        fn calcNeighborBitsum(self: *Self, is_wall: bool, x: usize, y: usize) u8 {
            var result: u8 = 0;
            inline for (self.getMooreNeighborhood(x, y), 0..) |neighbor_is_wall, i| {
                if (is_wall == neighbor_is_wall) {
                    result += 1 << i;
                }
            }
            return result;
        }

        fn getMooreNeighborhood(self: *Self, x: usize, y: usize) [8]bool {
            // TODO: Can return a u8 here (bits) instead. Skip own tile
            var result: [8]bool = @splat(false);

            // Top row
            if (x > 0 and y > 0) result[0] = self.tiles.get(x - 1, y - 1).is_wall;
            if (y > 0) result[1] = self.tiles.get(x, y - 1).is_wall;
            if (x < width - 1 and y > 0) result[2] = self.tiles.get(x + 1, y - 1).is_wall;

            // Middle row
            if (x > 0) result[3] = self.tiles.get(x - 1, y).is_wall;
            // NOTE: Skip own tile
            // if (true) result[4] = self.tiles.get(x, y).is_wall;
            if (x < width - 1) result[4] = self.tiles.get(x + 1, y).is_wall;

            // Bottom row
            if (x > 0 and y < height - 1) result[5] = self.tiles.get(x - 1, y + 1).is_wall;
            if (y < height - 1) result[6] = self.tiles.get(x, y + 1).is_wall;
            if (x < width - 1 and y < height - 1) result[7] = self.tiles.get(x + 1, y + 1).is_wall;

            return result;
        }

        pub fn render(self: *Self) void {
            const window: ArrayWindow = .{
                .x = @as(usize, @intFromFloat(@max(0, @floor(Game.camera.viewport.x / tile_size)))),
                .y = @as(usize, @intFromFloat(@max(0, @floor(Game.camera.viewport.y / tile_size)))),
                .w = @as(usize, @intFromFloat(@ceil(Game.camera.viewport.w / tile_size))) + 1,
                .h = @as(usize, @intFromFloat(@ceil(Game.camera.viewport.h / tile_size))) + 1,
            };

            // Render floor tiles
            {
                var iter = self.tiles.window(window);
                while (iter.next()) |e| {
                    if (e.t.floor_image_index >= 0) {
                        const sprite_rect = self.floor_tiles_sheet.sprites[@intCast(e.t.floor_image_index)];
                        Game.renderTexture(self.floor_tiles_sheet.sheet, sprite_rect, .{
                            .x = @as(f32, @floatFromInt(e.x)) * tile_size,
                            .y = @as(f32, @floatFromInt(e.y)) * tile_size,
                            .w = sprite_rect.w,
                            .h = sprite_rect.h,
                        });
                    }
                }
            }

            // Render wall tiles
            {
                var iter = self.tiles.window(window);
                while (iter.next()) |e| {
                    if (e.t.wall_image_index >= 0) {
                        const sprite_rect = self.wall_tiles_sheet.sprites[@intCast(e.t.wall_image_index)];
                        Game.renderTexture(self.wall_tiles_sheet.sheet, sprite_rect, .{
                            .x = @as(f32, @floatFromInt(e.x)) * tile_size,
                            .y = @as(f32, @floatFromInt(e.y)) * tile_size,
                            .w = sprite_rect.w,
                            .h = sprite_rect.h,
                        });

                        Game.setBlendMode(.blend);
                        Game.fillRect(.{
                            .x = @as(f32, @floatFromInt(e.x)) * tile_size,
                            .y = @as(f32, @floatFromInt(e.y)) * tile_size,
                            .w = sprite_rect.w,
                            .h = sprite_rect.h,
                        }, .{ .r = 0, .g = 100, .b = 0, .a = 100 });
                    }
                }
            }
        }

        pub fn getPotentialArea(shape: *const CollisionShape, start_loc: Vector, movement: Vector) ArrayWindow {
            switch (shape.*) {
                .aabb => |aabb| {
                    // Middle of the aabb is its location, need half size from its center.
                    const size = aabb.bottom_right.subtract(aabb.top_left).scale(0.5);
                    const min_x = aabb.top_left.x + @min(start_loc.x, start_loc.x + movement.x) - size.x;
                    const min_y = aabb.bottom_right.y + @min(start_loc.y, start_loc.y + movement.y) - size.y;
                    return ArrayWindow{
                        .x = @intFromFloat(@floor(min_x / tile_size)),
                        .y = @intFromFloat(@floor(min_y / tile_size)),
                        .w = @as(usize, @intFromFloat(@ceil(size.x / tile_size))) + 1,
                        .h = @as(usize, @intFromFloat(@ceil(size.y / tile_size))) + 1,
                    };
                },
                .circle => |circle| {
                    const dest = start_loc.add(movement);
                    const min_x = circle.center.x + @min(start_loc.x, dest.x) - circle.radius;
                    const max_x = circle.center.x + @max(start_loc.x, dest.x) + circle.radius;
                    const min_y = circle.center.y + @min(start_loc.y, dest.y) - circle.radius;
                    const max_y = circle.center.y + @max(start_loc.y, dest.y) + circle.radius;
                    const w = max_x - min_x;
                    const h = max_y - min_y;
                    return ArrayWindow{
                        .x = @intFromFloat(@floor(min_x / tile_size)),
                        .y = @intFromFloat(@floor(min_y / tile_size)),
                        .w = @as(usize, @intFromFloat(@ceil(w / tile_size))) + 1,
                        .h = @as(usize, @intFromFloat(@ceil(h / tile_size))) + 1,
                    };
                },
            }
        }

        fn getTileData(self: *Self, x: f32, y: f32, dx: f32, dy: f32) TileData {
            const _x = @as(usize, @intFromFloat(@floor(x / tile_size)));
            const _y = @as(usize, @intFromFloat(@floor(y / tile_size)));
            if (dx < 0) _x -= 1;
            if (dy < 0) _y -= 1;
            return .{
                .x = _x,
                .y = _y,
                .tile = self.tiles.get(_x, _y),
            };
        }

        fn round(x: f32) f32 {
            var result = x * 1_000_000;
            result = @round(result);
            return result * 0.000001;
        }

        pub fn raycast(self: *Self, start: Vector, end: Vector) []TileData {
            const max_iterations: usize = @intFromFloat(@ceil(end.distance(start) / (tile_size * 1.3)) * 2.0);

            const dx = end.x - start.x;
            const dy = end.y - start.y;

            const Direction = enum { positive, neutral, negative };
            const x_dir: Direction = if (dx == 0) .neutral else if (dx > 0) .positive else .negative;
            const y_dir: Direction = if (dy == 0) .neutral else if (dy > 0) .positive else .negative;

            var tiles_hit: std.ArrayList(TileData) = .empty;
            defer tiles_hit.deinit(self.alloc);

            // Add the starting tile
            tiles_hit.append(self.alloc, self.getTileData(start.x, start.y, dx, dy)) catch unreachable;

            const end_tile = self.getTileData(end.x, end.y, dx, dy);

            const slope = if (dx == 0) std.math.inf(f32) else @abs(round(dy / dx));
            var current_loc: Vector = start;

            const sign_x: i32 = @intFromFloat(std.math.sign(dx));
            const sign_y: i32 = @intFromFloat(std.math.sign(dy));
            const sign_joined: f32 = @floatFromInt(sign_x | sign_y);

            for (0..max_iterations) |i| {
                std.log.err("x: {}, y: {}", .{ x_dir, y_dir });
                const dist_to_tile: Vector = .{
                    .x = switch (x_dir) {
                        .neutral => std.math.inf(f32),
                        .positive => tile_size - round(@mod(current_loc.x, tile_size)),
                        .negative => blk: {
                            const res = -1.0 * round(@mod(current_loc.x, tile_size));
                            if (res == 0) {
                                break :blk -16.0;
                            }
                            break :blk res;
                        },
                    },
                    .y = switch (y_dir) {
                        .neutral => std.math.inf(f32),
                        .positive => tile_size - round(@mod(current_loc.y, tile_size)),
                        .negative => blk: {
                            const res = -1.0 * round(@mod(current_loc.y, tile_size));
                            if (res == 0) {
                                break :blk -16.0;
                            }
                            break :blk res;
                        },
                    },
                };

                std.log.err("curr: {}", .{current_loc});
                std.log.err("dist: {}", .{dist_to_tile});

                if (@abs(dist_to_tile.x * slope) < @abs(dist_to_tile.y)) {
                    std.log.err("Move in X direction...\n", .{});
                    switch (x_dir) {
                        .neutral => unreachable,
                        .positive, .negative => {
                            current_loc.x += dist_to_tile.x;
                            current_loc.y += sign_joined * round(dist_to_tile.x * slope);
                        },
                    }
                } else {
                    std.log.err("Move in Y direction...", .{});
                    switch (y_dir) {
                        .neutral => unreachable,
                        .positive, .negative => {
                            current_loc.x += sign_joined * round(dist_to_tile.y / slope);
                            current_loc.y += dist_to_tile.y;
                            std.log.err("New Y: {}\n", .{current_loc.y});
                        },
                    }
                }

                const current = self.getTileData(current_loc.x, current_loc.y, dx, dy);
                tiles_hit.append(self.alloc, current) catch unreachable;

                if (current.x == end_tile.x and current.y == end_tile.y) break;

                if (builtin.mode == .Debug and i == max_iterations - 1) {
                    std.log.err("Failed to find raycast in {} iterations", .{i + 1});
                }
            }
            return tiles_hit.toOwnedSlice(self.alloc) catch unreachable;
        }
    };
}
