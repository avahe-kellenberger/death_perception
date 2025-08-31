const std = @import("std");

pub fn Array2D(T: type, comptime width: usize, comptime height: usize) type {
    return struct {
        pub const Self = @This();

        values: [width * height]T = undefined,

        pub fn init() Array2D(T, width, height) {
            return .{};
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

        pub fn iterator(self: *Self) Iterator(T, width, height) {
            return Iterator(T, width, height).init(self);
        }
    };
}

fn Iterator(comptime T: type, comptime width: usize, comptime height: usize) type {
    const Result = struct { t: *T, x: usize, y: usize };

    return struct {
        pub const Self = @This();

        arr: *Array2D(T, width, height),
        i: u64 = 0,

        pub fn init(arr: *Array2D(T, width, height)) Iterator(T, width, height) {
            return .{ .arr = arr };
        }

        pub fn next(self: *Self) ?Result {
            defer self.i += 1;

            const x: usize = std.math.mod(u64, self.i, width) catch unreachable;
            const y: usize = @divTrunc(self.i, width);
            if (x >= width or y >= height) return null;

            return .{
                .t = self.arr.get(x, y),
                .x = x,
                .y = y,
            };
        }
    };
}

test {
    const Tile = struct {
        x: usize = 0,
        y: usize = 0,
    };

    var list: Array2D(Tile, 3, 4) = .init();
    var iter = list.iterator();
    while (iter.next()) |e| {
        // Initialize all tiles
        e.t.* = .{};
        try std.testing.expectEqual(e.t.x, 0);
        try std.testing.expectEqual(e.t.y, 0);
    }
}
