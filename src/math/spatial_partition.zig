const std = @import("std");

const Game = @import("../game.zig");

const array_2d = @import("../array_2d.zig");
const Array2D = array_2d.Array2D;
const ArrayWindow = array_2d.ArrayWindow;

const Node = std.DoublyLinkedList.Node;

pub fn SpatialPartition(
    T: type,
    comptime width: u32,
    comptime height: u32,
    comptime tile_size: u32,
    comptime tile_scalar: u32,
) type {
    return struct {
        pub const Self = @This();
        pub const grid_width = width;
        pub const grid_height = height;

        grid: std.AutoHashMap(u64, std.ArrayList(*T)),

        pub fn init() Self {
            return .{ .grid = .init(Game.alloc) };
        }

        pub fn deinit(self: *Self) void {
            var list_iter = self.grid.valueIterator();
            while (list_iter.next()) |*list| {
                list.*.deinit(Game.alloc);
            }
            self.grid.deinit();
        }

        fn toKey(x: u32, y: u32) u64 {
            var key: u64 = @intCast(x);
            key <<= 32;
            key |= y;
            return key;
        }

        pub fn insertAt(self: *Self, x: u32, y: u32, t: *T) void {
            const entry = self.grid.getOrPut(toKey(x, y)) catch unreachable;
            if (!entry.found_existing) entry.value_ptr.* = .empty;
            entry.value_ptr.append(Game.alloc, t) catch unreachable;
        }

        // pub fn insert(self: *Self, t: *T) void {
        //     // TODO: Insert based on T.collision_shape
        //     const entry = self.grid.getOrPut(toKey(x, y)) catch unreachable;
        //     if (!entry.found_existing) entry.value_ptr.* = .empty;
        //     entry.value_ptr.append(Game.alloc, t) catch unreachable;
        // }

        pub fn get(self: *Self, x: u32, y: u32) ?std.ArrayList(*T) {
            return self.grid.get(toKey(x, y));
        }

        pub fn window(self: *Self, win: ArrayWindow) Iterator {
            const x = @min(win.x, width);
            const y = @min(win.y, height);
            const w = @min(win.w, width - x);
            const h = if (w != 0) @min(win.h, height - y) else 0;
            return Iterator.init(self, .{ .x = x, .y = y, .w = w, .h = h });
        }

        pub fn render(_: *Self) void {
            for (0..height) |y| for (0..width) |x| {
                Game.drawRect(.{
                    .x = @floatFromInt(x * tile_size * tile_scalar),
                    .y = @floatFromInt(y * tile_size * tile_scalar),
                    .w = @floatFromInt(tile_size * tile_scalar),
                    .h = @floatFromInt(tile_size * tile_scalar),
                });
            };
        }

        pub const Iterator = struct {
            partition: *Self,

            // Window
            win_x: u32, // inclusive
            win_max_x: u32, // exclusive
            win_max_y: u32, // exclusive

            // State
            x: u32,
            y: u32,

            // Pointers of data that have already been returned
            returned_data: std.AutoHashMap(*T, void),
            current_list: ?std.ArrayList(*T) = null,
            current_list_i: usize = 0,

            pub fn init(self: *Self, win: ArrayWindow) Iterator {
                return Iterator{
                    .partition = self,
                    .win_x = @intCast(win.x),
                    .win_max_x = @intCast(win.x + win.w),
                    .win_max_y = @intCast(win.y + win.h),
                    .x = @intCast(win.x),
                    .y = @intCast(win.y),
                    .returned_data = .init(Game.alloc),
                };
            }

            pub fn deinit(self: *Iterator) void {
                self.returned_data.deinit();
            }

            pub fn next(self: *Iterator) ?*T {
                outer: while (self.y < self.win_max_y) {
                    if (self.current_list == null) {
                        self.current_list = self.partition.get(self.x, self.y);
                        self.current_list_i = 0;
                        if (self.current_list == null) {
                            std.log.err("Nothing at {}, {}", .{ self.x, self.y });
                            self.advancePosition();
                            continue;
                        }
                    }

                    if (self.current_list_i >= self.current_list.?.items.len) {
                        self.current_list = null;
                        self.current_list_i = 0;
                        self.advancePosition();
                        continue;
                    }

                    var t: *T = self.current_list.?.items[self.current_list_i];
                    defer self.current_list_i += 1;

                    while (self.returned_data.contains(t)) {
                        self.current_list_i += 1;

                        if (self.current_list_i >= self.current_list.?.items.len) {
                            self.current_list = null;
                            self.current_list_i = 0;
                            self.advancePosition();
                            continue :outer;
                        }
                        t = self.current_list.?.items[self.current_list_i];
                    }
                    std.log.err("x: {}, y: {}, i: {}, len: {}", .{
                        self.x, self.y, self.current_list_i, self.current_list.?.items.len,
                    });
                    self.returned_data.put(t, {}) catch unreachable;
                    return t;
                }
                self.deinit();
                return null;
            }

            fn advancePosition(self: *Iterator) void {
                self.x += 1;
                if (self.x >= self.win_max_x) {
                    self.y += 1;
                    self.x = self.win_x;
                }
                std.log.err("advancePosition: {}, {}", .{ self.x, self.y });
            }
        };
    };
}

test {
    Game.alloc = std.testing.allocator;

    // Testing 3x3 grid:
    // 1 2 0
    // 0 2 1
    // 1 0 1

    const Foo = struct { id: usize };
    var partition = SpatialPartition(Foo, 3, 3).init();
    defer partition.deinit();

    // 1 2 0
    var foo1: Foo = .{ .id = 1 };
    var foo2: Foo = .{ .id = 2 };
    var foo3: Foo = .{ .id = 3 };
    // 1
    partition.insert(0, 0, &foo1);
    // 2
    partition.insert(1, 0, &foo1);
    partition.insert(1, 0, &foo2);
    partition.insert(1, 0, &foo3);
    // 0
    //

    // 0 2 1
    var foo4: Foo = .{ .id = 4 };
    var foo5: Foo = .{ .id = 5 };
    var foo6: Foo = .{ .id = 6 };
    // 0
    //
    // 2
    partition.insert(1, 1, &foo4);
    partition.insert(1, 1, &foo5);
    // 1
    partition.insert(2, 1, &foo6);

    // 1 0 1
    var foo7: Foo = .{ .id = 7 };
    var foo8: Foo = .{ .id = 8 };
    // 1
    partition.insert(0, 2, &foo7);
    // 0
    //
    // 1
    partition.insert(2, 2, &foo8);

    // Assertions

    // 1 2 0
    if (partition.get(0, 0)) |list| {
        try std.testing.expect(list.items.len == 1);
    } else try std.testing.expect(false);

    if (partition.get(1, 0)) |list| {
        try std.testing.expect(list.items.len == 3);
    } else try std.testing.expect(false);

    try std.testing.expectEqual(null, partition.get(2, 0));

    // 0 2 1
    try std.testing.expectEqual(null, partition.get(0, 1));

    if (partition.get(1, 1)) |list| {
        try std.testing.expect(list.items.len == 2);
    } else try std.testing.expect(false);

    if (partition.get(2, 1)) |list| {
        try std.testing.expect(list.items.len == 1);
    } else try std.testing.expect(false);

    // 1 0 1
    if (partition.get(0, 2)) |list| {
        try std.testing.expect(list.items.len == 1);
    } else try std.testing.expect(false);

    try std.testing.expectEqual(null, partition.get(1, 2));

    if (partition.get(2, 2)) |list| {
        try std.testing.expect(list.items.len == 1);
    } else try std.testing.expect(false);

    // Verify iterator works properly
    var iter = partition.window(.{ .x = 0, .y = 0, .w = 3, .h = 3 });
    var i: usize = 0;
    while (iter.next()) |foo| {
        try std.testing.expectEqual(i + 1, foo.id);
        i += 1;
    }
    try std.testing.expectEqual(8, i);
}
