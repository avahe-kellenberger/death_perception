const std = @import("std");
const builtin = @import("builtin");

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
const Line = @import("math/collisionshape.zig").Line;

const sat = @import("math/sat.zig");
const CollisionResult = sat.CollisionResult;

const Color = @import("color.zig").Color;

pub const TileKind = enum { floor, wall, corner, inner };

pub const Tile = struct {
    floor_image_index: i32 = -1,
    wall_image_index: i32 = -1,
    neighbors: NeighborTiles = .{},
    kind: TileKind = .floor,

    pub fn isBoundary(t: Tile) bool {
        return t.kind == .wall or t.kind == .corner;
    }
};

const NeighborTiles = packed struct(u8) {
    top_left: bool = false,
    top: bool = false,
    top_right: bool = false,
    left: bool = false,
    right: bool = false,
    bottom_left: bool = false,
    bottom: bool = false,
    bottom_right: bool = false,
};

pub const TileData = struct {
    tile: *Tile,
    tile_x: usize,
    tile_y: usize,
    x: f32,
    y: f32,
};

pub const Body = struct {
    pub const Self = @This();
    loc: Vector,
    velocity: Vector,
    shape: CollisionShape,
    pub fn update(_: *Self, _: f32) void {}
};

pub fn Map(comptime width: usize, comptime height: usize, _tile_size: f32) type {
    return struct {
        pub const Self = @This();
        pub const tile_size: f32 = _tile_size;
        pub const tile_diagonal_len: f32 = _tile_size * std.math.sqrt(2.0);
        pub const collision_shape: CollisionShape = .{
            .aabb = .init(vector(0, 0), vector(_tile_size, _tile_size)),
        };

        floor_tiles_sheet: Spritesheet,
        wall_tiles_sheet: Spritesheet,
        tiles: *Array2D(Tile, width, height),

        lines: std.ArrayList(Line) = .empty,

        pub fn init(
            floor_tiles_sheet: Spritesheet,
            wall_tiles_sheet: Spritesheet,
            density: f32,
            border_thickness: usize,
        ) Map(width, height, _tile_size) {
            var tiles = Game.alloc.create(Array2D(Tile, width, height)) catch unreachable;
            tiles.setAllValues(Tile{});

            var result = Map(width, height, _tile_size){
                .floor_tiles_sheet = floor_tiles_sheet,
                .wall_tiles_sheet = wall_tiles_sheet,
                .tiles = tiles,
            };

            var iter = result.tiles.iterator();
            while (iter.next()) |e| {
                // Initialize all tiles
                e.t.* = .{};
                if (e.x < border_thickness + 1 or
                    e.x >= (width - border_thickness - 1) or
                    e.y < border_thickness + 1 or
                    e.y >= (height - border_thickness - 1) or
                    (density > 0 and density >= rand(f32, 0, 100)))
                {
                    e.t.kind = .wall;
                }
            }

            // Create basic map layout
            processCellularAutomata(&result);
            // Eliminate any smaller secluded rooms that were generated
            fillSmallerRooms(&result) catch unreachable;
            // Select correct images after map has been generated
            determineUniqueTileData(&result);

            result.lines = result.determineLines();

            return result;
        }

        pub fn deinit(self: *Self) void {
            Game.alloc.destroy(self.tiles);
        }

        fn processCellularAutomata(self: *Self) void {
            const max_iterations = 100;
            var failed = true;

            for (0..max_iterations) |i| {
                var has_changed = false;
                var iter = self.tiles.iterator();
                while (iter.next()) |e| {
                    const bitsum: u8 = @bitCast(self.getMooreNeighborhood(e.x, e.y));
                    var num_neighboring_walls: u16 = @popCount(bitsum);

                    const was_wall = e.t.kind == .wall;
                    if (was_wall) num_neighboring_walls += 1;

                    const is_wall = num_neighboring_walls > 4;
                    if (was_wall != is_wall) {
                        has_changed = true;
                        e.t.kind = if (is_wall) .wall else .floor;
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
                for (rooms.items) |room| Game.alloc.free(room);
                rooms.deinit(Game.alloc);
            }

            var iter = self.tiles.iterator();
            while (iter.next()) |e| {
                if (e.t.kind == .wall) continue;

                // Found a floor tile, skip if we've seen it before
                if (visited.get(e.x, e.y).*) continue;

                // New tile we haven't seen before!
                // Start flood fill for current room
                var room: std.ArrayList(Coordinate) = .empty;
                defer room.deinit(Game.alloc);

                // Flood fill find all connected floor tiles
                var queue: std.ArrayList(Coordinate) = .empty;
                defer queue.deinit(Game.alloc);

                try queue.append(Game.alloc, .{ .x = e.x, .y = e.y });
                while (queue.pop()) |n| {
                    if (self.tiles.get(n.x, n.y).kind == .wall or visited.get(n.x, n.y).*) continue;
                    // Add tile to the current room
                    try room.append(Game.alloc, n);
                    visited.set(n.x, n.y, true);

                    if (n.x > 0) try queue.append(Game.alloc, .{
                        .x = n.x - 1,
                        .y = n.y,
                    });

                    if (n.x + 1 < width) try queue.append(Game.alloc, .{
                        .x = n.x + 1,
                        .y = n.y,
                    });

                    if (n.y > 0) try queue.append(Game.alloc, .{
                        .x = n.x,
                        .y = n.y - 1,
                    });

                    if (n.y + 1 < height) try queue.append(Game.alloc, .{
                        .x = n.x,
                        .y = n.y + 1,
                    });
                }

                try rooms.append(Game.alloc, try room.toOwnedSlice(Game.alloc));
            }

            // Sort rooms by size in descending order
            std.mem.sort([]Coordinate, rooms.items, {}, compareRooms);

            // Fill every room except the largest
            for (rooms.items, 0..) |room, i| {
                if (i == 0) continue;
                for (room) |coord| {
                    var tile = self.tiles.get(coord.x, coord.y);
                    tile.kind = .wall;
                }
            }
        }

        fn compareRooms(_: void, a: []Coordinate, b: []Coordinate) bool {
            return a.len > b.len;
        }

        fn determineUniqueTileData(self: *Self) void {
            {
                var iter = self.tiles.iterator();
                while (iter.next()) |e| e.t.neighbors = self.getMooreNeighborhood(e.x, e.y);
            }

            var iter = self.tiles.iterator();
            while (iter.next()) |e| {
                const bitsum: u8 = @bitCast(e.t.neighbors);
                if (e.t.kind == .wall) {
                    e.t.floor_image_index = switch (bitsum) {
                        // 212, 232, 240, 244, 248, 249, 252 => 0,
                        // 105, 233 => 3,
                        else => -1,
                    };

                    switch (bitsum) {
                        255 => {
                            e.t.wall_image_index = 0;
                            e.t.kind = .inner;
                        },
                        107, 111, 235 => e.t.wall_image_index = 1,
                        182, 183, 214, 215, 246 => e.t.wall_image_index = 2,
                        180, 212, 240, 244 => {
                            e.t.wall_image_index = 3;
                            e.t.kind = .corner;
                        },
                        211 => {
                            e.t.wall_image_index = 3;
                            e.t.kind = .wall;
                        },
                        191, 248, 249, 252 => e.t.wall_image_index = 4,
                        105, 216, 217, 232, 233 => {
                            e.t.wall_image_index = 5;
                            e.t.kind = .corner;
                        },
                        22, 23, 54, 55, 150, 151 => {
                            e.t.wall_image_index = 6;
                            e.t.kind = .corner;
                        },
                        31, 63, 159 => e.t.wall_image_index = 7,
                        11, 15, 43, 47, 91, 95, 139 => {
                            e.t.wall_image_index = 8;
                            e.t.kind = .corner;
                        },
                        203 => {
                            e.t.wall_image_index = 8;
                            e.t.kind = .wall;
                        },
                        127 => {
                            e.t.wall_image_index = 9;
                            e.t.kind = .inner;
                        },
                        223 => {
                            e.t.wall_image_index = 10;
                            e.t.kind = .inner;
                        },
                        251 => {
                            e.t.wall_image_index = 11;
                            e.t.kind = .inner;
                        },
                        254 => {
                            e.t.wall_image_index = 12;
                            e.t.kind = .inner;
                        },
                        219 => {
                            e.t.wall_image_index = 14;
                            e.t.kind = .inner;
                        },
                        else => {
                            e.t.wall_image_index = 0;
                            e.t.kind = .inner;
                        },
                    }
                } else {
                    e.t.floor_image_index = switch (bitsum) {
                        3, 6, 7, 22, 23, 150 => 2,
                        9, 41, 105 => 3,
                        1 => 4,
                        11, 15, 43 => 5,
                        // This is usually image index 0, but we don't need to draw the empty tile.
                        else => -1,
                    };
                    e.t.kind = .floor;
                }
            }
        }

        fn getMooreNeighborhood(self: *Self, x: usize, y: usize) NeighborTiles {
            return .{
                .top_left = x > 0 and y > 0 and self.tiles.get(x - 1, y - 1).kind == .wall,
                .top = y > 0 and self.tiles.get(x, y - 1).kind == .wall,
                .top_right = x < width - 1 and y > 0 and self.tiles.get(x + 1, y - 1).kind == .wall,
                .left = x > 0 and self.tiles.get(x - 1, y).kind == .wall,
                .right = x < width - 1 and self.tiles.get(x + 1, y).kind == .wall,
                .bottom_left = x > 0 and y < height - 1 and self.tiles.get(x - 1, y + 1).kind == .wall,
                .bottom = y < height - 1 and self.tiles.get(x, y + 1).kind == .wall,
                .bottom_right = x < width - 1 and y < height - 1 and self.tiles.get(x + 1, y + 1).kind == .wall,
            };
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
                        const sprite_rect = self.floor_tiles_sheet.index(@intCast(e.t.floor_image_index));
                        Game.renderTexture(self.floor_tiles_sheet.texture, sprite_rect, .{
                            .x = @as(f32, @floatFromInt(e.x)) * tile_size,
                            .y = @as(f32, @floatFromInt(e.y)) * tile_size,
                            .w = tile_size,
                            .h = tile_size,
                        });
                    }
                }
            }

            // Game.fillRect(Game.camera.viewport, Color.red);
            // Game.renderer.setDrawBlendMode(.none) catch unreachable;
            // Game.fillRect(.{
            //     .x = Game.camera.viewport.x + 50.0,
            //     .y = Game.camera.viewport.y + 50.0,
            //     .w = 100.0,
            //     .h = Game.camera.viewport.x,
            // }, Color.transparent);

            // Render wall tiles
            {
                var iter = self.tiles.window(window);
                while (iter.next()) |e| {
                    if (e.t.wall_image_index >= 0) {
                        const sprite_rect = self.wall_tiles_sheet.index(@intCast(e.t.wall_image_index));
                        Game.renderTexture(self.wall_tiles_sheet.texture, sprite_rect, .{
                            .x = @as(f32, @floatFromInt(e.x)) * tile_size,
                            .y = @as(f32, @floatFromInt(e.y)) * tile_size,
                            .w = tile_size,
                            .h = tile_size,
                        });

                        // if (e.t.kind == .wall or e.t.kind == .corner) {
                        //     Game.drawRect(.{
                        //         .x = @as(f32, @floatFromInt(e.x)) * tile_size,
                        //         .y = @as(f32, @floatFromInt(e.y)) * tile_size,
                        //         .w = tile_size,
                        //         .h = tile_size,
                        //     }, Color.green);
                        // }
                    }
                }
            }

            var iter = self.tiles.window(window);
            while (iter.next()) |e| {
                const bitsum: u8 = @bitCast(e.t.neighbors);
                var buf: [1 + std.fmt.count("{d}", .{std.math.maxInt(i32)})]u8 = undefined;
                const str = std.fmt.bufPrintZ(&buf, "{d}", .{bitsum}) catch unreachable;

                Game.renderDebugTextInGame(.{
                    .x = @as(f32, @floatFromInt(e.x)) * tile_size + tile_size * 0.5 - 12,
                    .y = @as(f32, @floatFromInt(e.y)) * tile_size + tile_size * 0.5 - 4,
                }, str);
            }

            Game.setRenderColor(Color.red);
            for (self.lines.items) |line| {
                Game.drawLine(line);
            }
        }

        pub fn getPotentialArea(
            shape: *const CollisionShape,
            start_loc: Vector,
            movement: Vector,
        ) ArrayWindow {
            switch (shape.*) {
                .aabb => |aabb| {
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
                .line => unreachable,
            }
        }

        pub fn raycast(self: *Self, start: Vector, end: Vector) RaycastIterator {
            return .init(self, start, end);
        }

        pub const RaycastIterator = struct {
            map: *Self,
            start: Vector,
            end: Vector,

            dx: f32,
            dy: f32,
            sign_x: isize,
            sign_y: isize,
            slope: f32,

            current_loc: Vector,
            next_tile: ?TileData,

            pub fn init(map: *Self, start: Vector, end: Vector) RaycastIterator {
                const dx = end.x - start.x;
                const dy = end.y - start.y;
                const sign_x: isize = @intFromFloat(std.math.sign(dx));
                const sign_y: isize = @intFromFloat(std.math.sign(dy));
                const slope = if (dx == 0) std.math.inf(f32) else dy / dx;
                return .{
                    .map = map,
                    .start = start,
                    .end = end,
                    .dx = dx,
                    .dy = dy,
                    .sign_x = sign_x,
                    .sign_y = sign_y,
                    .slope = slope,
                    .current_loc = start,
                    .next_tile = determineTile(map, start),
                };
            }

            fn getTileData(iter: *RaycastIterator, tile_x: usize, tile_y: usize) TileData {
                return .{
                    .x = iter.current_loc.x,
                    .y = iter.current_loc.y,
                    .tile_x = tile_x,
                    .tile_y = tile_y,
                    .tile = iter.map.tiles.get(tile_x, tile_y),
                };
            }

            fn dispToTile(tile_coord: usize, loc: f32, sign: isize) f32 {
                if (sign > 0) return tile_size + @as(f32, @floatFromInt(tile_coord)) * tile_size - loc;
                return @as(f32, @floatFromInt(tile_coord)) * tile_size - loc;
            }

            fn determineTile(map: *Self, current_loc: Vector) TileData {
                const tile_x = @as(usize, @intFromFloat(@floor(current_loc.x / tile_size)));
                const tile_y = @as(usize, @intFromFloat(@floor(current_loc.y / tile_size)));
                return .{
                    .x = current_loc.x,
                    .y = current_loc.y,
                    .tile_x = tile_x,
                    .tile_y = tile_y,
                    .tile = map.tiles.get(tile_x, tile_y),
                };
            }

            pub fn next(iter: *RaycastIterator) ?TileData {
                const return_tile = iter.next_tile;
                if (return_tile) |rt| {
                    const disp_x = dispToTile(rt.tile_x, iter.current_loc.x, iter.sign_x);
                    const disp_y = dispToTile(rt.tile_y, iter.current_loc.y, iter.sign_y);
                    const slope_diff = @abs(disp_y) - @abs(disp_x * iter.slope);
                    if (slope_diff > 0) {
                        iter.current_loc.x += disp_x;
                        iter.current_loc.y += disp_x * iter.slope;
                        const new_x = @as(isize, @intCast(rt.tile_x)) + iter.sign_x;
                        if (new_x < 0 or new_x >= width) {
                            iter.next_tile = null;
                        } else {
                            iter.next_tile = iter.getTileData(@as(usize, @intCast(new_x)), rt.tile_y);
                        }
                    } else if (slope_diff < 0) {
                        iter.current_loc.x += disp_y / iter.slope;
                        iter.current_loc.y += disp_y;
                        const new_y = @as(isize, @intCast(rt.tile_y)) + iter.sign_y;
                        if (new_y < 0 or new_y >= height) {
                            iter.next_tile = null;
                        } else {
                            iter.next_tile = iter.getTileData(rt.tile_x, @as(usize, @intCast(new_y)));
                        }
                    } else {
                        // Going through intersection x and y at the same time
                        iter.current_loc.x += disp_x;
                        iter.current_loc.y += disp_y;
                        const new_x = @as(isize, @intCast(rt.tile_x)) + iter.sign_x;
                        const new_y = @as(isize, @intCast(rt.tile_y)) + iter.sign_y;
                        if (new_x < 0 or new_x >= width or new_y < 0 or new_y >= height) {
                            iter.next_tile = null;
                        } else {
                            iter.next_tile = iter.getTileData(
                                @as(usize, @intCast(new_x)),
                                @as(usize, @intCast(new_y)),
                            );
                        }
                    }

                    if (@abs(iter.current_loc.x - iter.start.x) >= @abs(iter.dx)) {
                        if (@abs(iter.current_loc.y - iter.start.y) >= @abs(iter.dy)) {
                            iter.next_tile = null;
                        }
                    }
                }
                return return_tile;
            }
        };

        pub fn CollisionIterator(T: type) type {
            return struct {
                pub const CollisionIter = @This();
                map: *Self,
                body: *T,
                shape: CollisionShape,
                dt: f32,
                is_fast_object: bool,

                pub fn init(map: *Self, body: *T, shape: CollisionShape, dt: f32) CollisionIter {
                    return .{
                        .map = map,
                        .body = body,
                        .shape = shape,
                        .dt = dt,
                        .is_fast_object = body.velocity.getMagnitude() * dt >= tile_size,
                    };
                }

                pub fn next(iter: *CollisionIter) ?CollisionResult {
                    const start_loc = iter.body.loc;
                    iter.body.update(iter.dt);

                    const tile_shape: CollisionShape = Self.collision_shape;

                    // TODO: Get different tiles if iter.body.is_fast_object
                    const movement_area = Self.getPotentialArea(
                        &iter.shape,
                        iter.body.loc,
                        iter.body.loc.subtract(start_loc),
                    );

                    var tile_iter = iter.map.tiles.window(movement_area);
                    while (tile_iter.next()) |t| {
                        if (t.t.kind != .wall and t.t.kind != .corner) continue;

                        const tile_loc = vector(
                            @as(f32, @floatFromInt(t.x)) * Self.tile_size,
                            @as(f32, @floatFromInt(t.y)) * Self.tile_size,
                        );
                        return sat.collides(
                            Game.alloc,
                            iter.body.loc,
                            iter.shape,
                            iter.body.loc.subtract(start_loc),
                            tile_loc,
                            tile_shape,
                            Vector.zero,
                        );
                    }
                    return null;
                }
            };
        }

        fn isVerticalWall(self: *Self, x: usize, y: usize, neighbors: NeighborTiles) bool {
            if (y >= height) return false;
            const t = self.tiles.get(x, y);
            return t.isBoundary() and neighbors.right == t.neighbors.right and neighbors.left == t.neighbors.left;
        }

        fn isHorizontalWall(self: *Self, x: usize, y: usize, neighbors: NeighborTiles) bool {
            if (x >= width) return false;
            const t = self.tiles.get(x, y);
            return t.isBoundary() and neighbors.top == t.neighbors.top and neighbors.bottom == t.neighbors.bottom;
        }

        pub fn determineLines(self: *Self) std.ArrayList(Line) {
            var lines: std.ArrayList(Line) = .empty;

            var iter = self.tiles.iterator();
            while (iter.next()) |e| {
                const t = e.t;
                if (!t.isBoundary()) continue;

                if (t.neighbors.left and t.neighbors.right) {
                    if (self.tiles.get(e.x - 1, e.y).isBoundary()) continue;
                } else {
                    // Vertical wall
                    var vertical_count: usize = 1;
                    while (self.isVerticalWall(e.x, e.y + vertical_count, t.neighbors)) {
                        vertical_count += 1;
                    }
                    if (!t.neighbors.left) {
                        const p1 = position(e.x, e.y);
                        const p2 = position(e.x, e.y + vertical_count);
                        lines.append(Game.alloc, .init(p1, p2)) catch unreachable;
                    } else if (!t.neighbors.right) {
                        const p1 = position(e.x + 1, e.y);
                        const p2 = position(e.x + 1, e.y + vertical_count);
                        lines.append(Game.alloc, .init(p2, p1)) catch unreachable;
                    }
                }

                if (t.neighbors.top and t.neighbors.bottom) {
                    if (self.tiles.get(e.x, e.y - 1).isBoundary()) continue;
                } else {
                    // Horizontal wall
                    var horizontal_count: usize = 1;
                    while (self.isHorizontalWall(e.x + horizontal_count, e.y, t.neighbors)) {
                        horizontal_count += 1;
                    }
                    if (!t.neighbors.top) {
                        const p1 = position(e.x, e.y);
                        const p2 = position(e.x + horizontal_count, e.y);
                        lines.append(Game.alloc, .init(p2, p1)) catch unreachable;
                    } else if (!t.neighbors.bottom) {
                        const p1 = position(e.x, e.y + 1);
                        const p2 = position(e.x + horizontal_count, e.y + 1);
                        lines.append(Game.alloc, .init(p1, p2)) catch unreachable;
                    }
                }

                Game.drawRect(.{
                    .x = @as(f32, @floatFromInt(e.x)) * tile_size,
                    .y = @as(f32, @floatFromInt(e.y)) * tile_size,
                    .w = tile_size,
                    .h = tile_size,
                }, Color.green);
            }
            return lines;
        }

        pub fn position(tile_x: usize, tile_y: usize) Vector {
            return .init(
                @as(f32, @floatFromInt(tile_x)) * tile_size,
                @as(f32, @floatFromInt(tile_y)) * tile_size,
            );
        }
    };
}
