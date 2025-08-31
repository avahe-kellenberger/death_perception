const std = @import("std");
const Allocator = std.mem.Allocator;
const sdl = @import("sdl3");
const rand = @import("random.zig").rand;
const Array2D = @import("array_2d.zig").Array2D;

const Tile = struct {
    floor_image_index: isize = -1,
    wall_image_index: isize = -1,
    neighbor_bit_sum: u8,
    is_wall: bool,
};

pub fn Map(comptime width: usize, comptime height: usize) type {
    return struct {
        pub const Self = @This();

        var floor_tile_sheet: sdl.surface.Surface = undefined;
        var wall_tile_sheet: sdl.surface.Surface = undefined;

        alloc: Allocator,
        tiles: Array2D(Tile, width, height),
        tile_size: usize,

        pub fn init(
            alloc: Allocator,
            tile_size: usize,
            density: f32,
            border_thickness: usize,
        ) !Map(width, height) {
            floor_tile_sheet = try sdl.image.loadFile("./assets/images/floor_tiles.png");
            wall_tile_sheet = try sdl.image.loadFile("./assets/images/wall_tiles.png");

            var result = Map(width, height){
                .alloc = alloc,
                .tiles = Array2D(Tile, width, height).init(),
                .tile_size = tile_size,
            };

            var iter = result.tiles.iterator();
            while (iter.next()) |e| {
                e.t.is_wall = (e.x < border_thickness or
                    e.x >= (width - border_thickness) or
                    e.y < border_thickness or
                    e.y >= (height - border_thickness) or
                    (density > 0 and density >= rand(f32, 0, 100)));
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
            _ = self;
            floor_tile_sheet.deinit();
            wall_tile_sheet.deinit();
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
            _ = self;
            //
        }

        fn getMooreNeighborhood(self: *Self, x: usize, y: usize) [9]bool {
            var result: [9]bool = @splat(true);

            // Top row
            if (x > 0 and y > 0) result[0] = self.tiles.get(x - 1, y - 1).is_wall;
            if (y > 0) result[1] = self.tiles.get(x, y - 1).is_wall;
            if (x < width - 1 and y > 0) result[2] = self.tiles.get(x + 1, y - 1).is_wall;

            // Middle row
            if (x > 0) result[3] = self.tiles.get(x - 1, y).is_wall;
            if (true) result[4] = self.tiles.get(x, y).is_wall;
            if (x < width - 1) result[5] = self.tiles.get(x + 1, y).is_wall;

            // Bottom row
            if (x > 0 and y < height - 1) result[6] = self.tiles.get(x - 1, y + 1).is_wall;
            if (y < height - 1) result[7] = self.tiles.get(x, y + 1).is_wall;
            if (x < width - 1 and y < height - 1) result[8] = self.tiles.get(x + 1, y + 1).is_wall;

            return result;
        }

        pub fn render(self: *Self, ctx: sdl.surface.Surface, offset_x: f32, offset_y: f32) !void {
            var iter = self.tiles.iterator();
            while (iter.next()) |e| {
                const tile_x = @as(f32, @floatFromInt(e.x * self.tile_size)) + offset_x;
                const tile_y = @as(f32, @floatFromInt(e.y * self.tile_size)) + offset_y;

                if (e.t.floor_image_index >= 0) {
                    // TODO: Tilesheets!
                }
            }
        }
    };
}

test {
    std.testing.log_level = .debug;

    @import("random.zig").init();

    var map = try Map(100, 100).init(std.testing.allocator, 32, 46.0, 4);
    defer map.deinit();

    var iter = map.tiles.iterator();
    var prev_y: usize = 0;
    while (iter.next()) |e| {
        if (e.y != prev_y) {
            std.debug.print("\n", .{});
            prev_y = e.y;
        }

        if (e.t.is_wall) {
            std.debug.print("XX", .{});
        } else {
            std.debug.print("  ", .{});
        }
    }
    std.debug.print("\n", .{});
}
