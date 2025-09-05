const std = @import("std");
const Allocator = std.mem.Allocator;

const sdl = @import("sdl3");
const Renderer = sdl.render.Renderer;
const FRect = sdl.rect.FRect;
const FPoint = sdl.rect.FPoint;
const IPoint = sdl.rect.IPoint;

const Game = @import("game.zig");
const rand = @import("random.zig").rand;
const Array2D = @import("array_2d.zig").Array2D;
const ArrayWindow = @import("array_2d.zig").ArrayWindow;
const Spritesheet = @import("spritesheet.zig").Spritesheet;

const Tile = struct {
    floor_image_index: isize = -1,
    wall_image_index: isize = -1,
    neighbor_bit_sum: u8 = 0,
    is_wall: bool = false,
};

pub fn Map(comptime width: usize, comptime height: usize) type {
    return struct {
        pub const Self = @This();

        alloc: Allocator,
        floor_tiles_sheet: Spritesheet,
        wall_tiles_sheet: Spritesheet,
        tile_size: f32,
        tiles: Array2D(Tile, width, height),

        pub fn init(
            alloc: Allocator,
            floor_tiles_sheet: Spritesheet,
            wall_tiles_sheet: Spritesheet,
            tile_size: f32,
            density: f32,
            border_thickness: usize,
        ) Map(width, height) {
            var result = Map(width, height){
                .alloc = alloc,
                .floor_tiles_sheet = floor_tiles_sheet,
                .wall_tiles_sheet = wall_tiles_sheet,
                .tiles = Array2D(Tile, width, height).init(Tile{}),
                .tile_size = tile_size,
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
                .x = @as(usize, @intFromFloat(@max(0, @floor(Game.camera.viewport.x / self.tile_size)))),
                .y = @as(usize, @intFromFloat(@max(0, @floor(Game.camera.viewport.y / self.tile_size)))),
                .w = @as(usize, @intFromFloat(@ceil(Game.camera.viewport.w / self.tile_size))) + 1,
                .h = @as(usize, @intFromFloat(@ceil(Game.camera.viewport.h / self.tile_size))) + 1,
            };

            // Render floor tiles
            {
                var iter = self.tiles.window(window);
                while (iter.next()) |e| {
                    if (e.t.floor_image_index >= 0) {
                        const sprite_rect = self.floor_tiles_sheet.sprites[@intCast(e.t.floor_image_index)];
                        Game.renderTexture(self.floor_tiles_sheet.sheet, sprite_rect, .{
                            .x = calcTileLocation(e.x, self.tile_size),
                            .y = calcTileLocation(e.y, self.tile_size),
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
                            .x = calcTileLocation(e.x, self.tile_size),
                            .y = calcTileLocation(e.y, self.tile_size),
                            .w = sprite_rect.w,
                            .h = sprite_rect.h,
                        });
                    }
                }
            }
        }

        fn calcTileLocation(tile_coord: usize, tile_size: f32) f32 {
            return @as(f32, @floatFromInt(tile_coord)) * tile_size;
        }

        const TileHelpers = struct {
            current_tile: i32,
            tile_direction: f32,
            dt: f32,
            delta_tile: f32,
        };

        fn getTileHelpers(self: *Self, position: f32, ray_dist: f32) !TileHelpers {
            const current_tile = @floor(position / self.tile_size) + 1;

            var direction: f32 = 0;
            var dt: f32 = 0;

            if (direction > 0) {
                direction = 1;
                dt = ((current_tile + 0) * self.tile_size - position) / ray_dist;
            } else {
                direction = -1;
                dt = ((current_tile - 1) * self.tile_size - position) / ray_dist;
            }

            return TileHelpers{
                .current_tile = @intFromFloat(current_tile),
                .direction = direction,
                .dt = dt,
                .delta_tile = direction * self.tile_size / direction,
            };
        }

        const TileData = struct {
            tile: Tile,
            x: u32,
            y: u32,
        };

        // Caller owns the returned data.
        // pub fn raycast(self: *Self, loc: FPoint, vector: FPoint) []TileData {
        //     const helpers_x = self.getTileHelpers(loc.x, vector.x);
        //     const helpers_y = self.getTileHelpers(loc.x, vector.y);
        //
        //     const tile_x = helpers_x.current_tile;
        //     const tile_y = helpers_y.current_tile;
        //     var tile: IPoint = .{
        //         .x = helpers_x.current_tile,
        //         .y = helpers_y.current_tile,
        //     };
        //
        //     const tile_direction_x = helpers_x.tile_direction;
        //     var delta_time_x = helpers_x.dt;
        //     const delta_tile_x = helpers_x.delta_tile;
        //
        //     const tile_direction_y = helpers_y.tile_direction;
        //     var delta_time_y = helpers_y.dt;
        //     const delta_tile_y = helpers_y.delta_tile;
        //
        //     var total_distance: f32 = 0;
        //
        //     var tiles: std.ArrayList(TileData) = .empty;
        //     while (tile_x > 0 and tile_x <= self.width and tile_y > 0 and tile_y <= self.height) {
        //         self[tile_y][tile_x] = true;
        //         tiles.append(self.alloc, .{});
        //         // mark(ray.start_x + ray.dir_x * total_distance, ray.start_y + ray.dir_y * total_distance);
        //
        //         if (delta_time_x < delta_time_y) {
        //             tile_x += tile_direction_x;
        //             const delta = delta_time_x;
        //             total_distance += delta;
        //             delta_time_x += delta_tile_x - delta;
        //             delta_time_y -= delta;
        //         } else {
        //             tile_y += tile_direction_y;
        //             const delta = delta_time_y;
        //             total_distance += delta;
        //             delta_time_x -= delta;
        //             delta_time_y += delta_tile_y - delta;
        //         }
        //     }
        //     return tiles.toOwnedSlice(self.alloc);
        // }
    };
}
