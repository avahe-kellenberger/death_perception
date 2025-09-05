const std = @import("std");

pub const ArrayWindow = struct { x: usize, y: usize, w: usize, h: usize };

pub fn Array2D(T: type, comptime width: usize, comptime height: usize) type {
    comptime {
        if (width == 0) @compileError("width cannot be zero");
        if (height == 0) @compileError("height cannot be zero");
    }
    return struct {
        pub const Self = @This();

        values: [width * height]T = undefined,

        pub fn init(default: T) Self {
            var t: Self = .{};
            @memset(&t.values, default);
            return t;
        }

        pub fn get(self: *Self, x: usize, y: usize) *T {
            return &self.values[width * y + x];
        }

        pub fn set(self: *Self, x: usize, y: usize, t: T) void {
            self.values[width * y + x] = t;
        }

        /// Translates the coordinates into an index for direct access to `values`.
        pub fn getIndex(_: *Self, x: usize, y: usize) u64 {
            return width * y + x;
        }

        pub fn iterator(self: *Self) Iterator {
            return Iterator.init(self, .{
                .x = 0,
                .y = 0,
                .w = width,
                .h = height,
            });
        }

        pub fn window(
            self: *Self,
            win: ArrayWindow,
        ) Iterator {
            const x = @min(win.x, width);
            const y = @min(win.y, height);
            const w = @min(win.w, width - x);
            const h = if (w != 0) @min(win.h, height - y) else 0;
            return Iterator.init(
                self,
                .{
                    .x = x,
                    .y = y,
                    .w = w,
                    .h = h,
                },
            );
        }

        const Iterator = struct {
            const Result = struct { t: *T, x: usize, y: usize };

            arr: *Array2D(T, width, height),

            // Window
            win_x: usize, // inclusive
            win_max_x: usize, // exclusive
            win_max_y: usize, // exclusive

            // State
            x: usize,
            y: usize,

            pub fn init(arr: *Array2D(T, width, height), win: ArrayWindow) Iterator {
                return .{
                    .arr = arr,
                    .win_x = win.x,
                    .win_max_x = win.x + win.w,
                    .win_max_y = win.y + win.h,
                    .x = win.x,
                    .y = win.y,
                };
            }

            pub fn next(self: *Iterator) ?Result {
                defer self.x += 1;

                if (self.x >= self.win_max_x) {
                    self.x = self.win_x;
                    self.y += 1;
                }
                if (self.y >= self.win_max_y) return null;

                return .{
                    .t = self.arr.get(self.x, self.y),
                    .x = self.x,
                    .y = self.y,
                };
            }
        };
    };
}

test "init" {
    var list: Array2D(u32, 3, 4) = .init(42);
    var iter = list.iterator();
    while (iter.next()) |e| {
        try std.testing.expectEqual(e.t.*, 42);
    }
}

test "iterate over area" {
    var list: Array2D(u32, 3, 4) = .init(0);
    var iter = list.window(.{ .x = 1, .y = 0, .w = 1, .h = 2 });
    var count: usize = 0;
    while (iter.next()) |_| {
        count += 1;
    }
    try std.testing.expectEqual(count, 2);
}

test "no columns" {
    var list: Array2D(u32, 3, 4) = .init(0);
    var iter = list.window(.{ .x = 0, .y = 0, .w = 0, .h = 100 });
    while (iter.next()) |_| {
        try std.testing.expect(false);
    }
}

test "no rows" {
    var list: Array2D(u32, 3, 4) = .init(0);
    var iter = list.window(.{ .x = 0, .y = 0, .w = 100, .h = 0 });
    while (iter.next()) |_| {
        try std.testing.expect(false);
    }
}

test "out of bounds" {
    var list: Array2D(u32, 3, 4) = .init(0);
    var iter = list.window(.{ .x = 5, .y = 0, .w = 10, .h = 10 });
    while (iter.next()) |_| {
        try std.testing.expect(false);
    }
}

test "1 column" {
    var list: Array2D(u32, 3, 4) = .init(0);
    var iter = list.window(.{ .x = 2, .y = 0, .w = 10, .h = 10 });
    var count: usize = 0;
    while (iter.next()) |_| {
        count += 1;
    }
    try std.testing.expectEqual(count, 4);
}

test "1 row" {
    var list: Array2D(u32, 3, 4) = .init(0);
    var iter = list.window(.{ .x = 1, .y = 3, .w = 10, .h = 10 });
    var count: usize = 0;
    while (iter.next()) |_| {
        count += 1;
    }
    try std.testing.expectEqual(count, 2);
}
