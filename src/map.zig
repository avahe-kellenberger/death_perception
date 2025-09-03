const std = @import("std");
const Allocator = std.mem.Allocator;

const sdl = @import("sdl3");
const Renderer = sdl.render.Renderer;
const Surface = sdl.surface.Surface;
const FRect = sdl.rect.FRect;
const FPoint = sdl.rect.FPoint;

const Camera = @import("camera.zig").Camera;
const rand = @import("random.zig").rand;
const Array2D = @import("array_2d.zig").Array2D;
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
        ) !Map(width, height) {
            var result = Map(width, height){
                .alloc = alloc,
                .floor_tiles_sheet = floor_tiles_sheet,
                .wall_tiles_sheet = wall_tiles_sheet,
                .tiles = Array2D(Tile, width, height).init(),
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
            try fillSmallerRooms(&result);
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
            var visited = Array2D(bool, width, height).init();

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
                        104, 105, 232, 233, 248, 249, 252 => 2,
                        22, 150, 214, 246 => 3,
                        254 => 4,
                        208, 212, 240, 244 => 5,
                        else => 0,
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

        pub fn render(self: *Self, ctx: Renderer, camera: *Camera, offset: FPoint) !void {
            // Render floor tiles
            {
                var iter = self.tiles.iterator();
                while (iter.next()) |e| {
                    if (e.t.floor_image_index >= 0) {
                        const sprite_rect = self.floor_tiles_sheet.sprites[@intCast(e.t.floor_image_index)];
                        const dest: FRect = .{
                            .x = calcTileLocation(e.x, self.tile_size, offset.x),
                            .y = calcTileLocation(e.y, self.tile_size, offset.y),
                            .w = sprite_rect.w,
                            .h = sprite_rect.h,
                        };
                        if (isOnScreen(dest, camera)) {
                            try ctx.renderTexture(self.floor_tiles_sheet.sheet, sprite_rect, dest);
                        }
                    }
                }
            }

            // Render wall tiles
            {
                var iter = self.tiles.iterator();
                while (iter.next()) |e| {
                    if (e.t.wall_image_index >= 0) {
                        const sprite_rect = self.wall_tiles_sheet.sprites[@intCast(e.t.wall_image_index)];
                        const dest: FRect = .{
                            .x = calcTileLocation(e.x, self.tile_size, offset.x),
                            .y = calcTileLocation(e.y, self.tile_size, offset.y),
                            .w = sprite_rect.w,
                            .h = sprite_rect.h,
                        };

                        if (isOnScreen(dest, camera)) {
                            try ctx.renderTexture(self.wall_tiles_sheet.sheet, sprite_rect, dest);
                        }
                    }
                }
            }
        }

        fn calcTileLocation(tile_coord: usize, tile_size: f32, offset: f32) f32 {
            const tile_coord_float: f32 = @floatFromInt(tile_coord);
            return @floor(tile_coord_float * tile_size + offset);
        }

        fn isOnScreen(r: FRect, camera: *Camera) bool {
            return !(r.x >= camera.viewport.w or
                r.x + r.w <= 0 or
                r.y >= camera.viewport.h or
                r.y + r.h <= 0);
        }
    };
}
