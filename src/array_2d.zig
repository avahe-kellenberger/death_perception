const std = @import("std");

pub fn Array2D(T: type, comptime width: u32, comptime height: u32) type {
    return struct {
        pub const Self = @This();

        values: [width * height]T = undefined,

        pub fn init() Array2D(T, width, height) {
            return .{};
        }

        pub fn get(self: *Self, x: u32, y: u32) *T {
            return &self.values[width * y + x];
        }

        /// Translates the coordinates into an index for direct access to `values`.
        pub fn getIndex(_: *Self, x: u32, y: u32) u64 {
            return width * y + x;
        }

        pub fn iterator(self: *Self) Iterator(T, width, height) {
            return Iterator(T, width, height).init(self);
        }
    };
}

fn Iterator(comptime T: type, comptime width: u32, comptime height: u32) type {
    const Result = struct { t: *T, x: u32, y: u32 };

    return struct {
        pub const Self = @This();

        arr: *Array2D(T, width, height),
        i: u64 = 0,

        pub fn init(arr: *Array2D(T, width, height)) Iterator(T, width, height) {
            return .{ .arr = arr };
        }

        pub fn next(self: *Self) ?Result {
            defer self.i += 1;

            const x: u32 = @intCast(std.math.mod(u64, self.i, width) catch unreachable);
            const y: u32 = @intCast(@divTrunc(self.i, width));
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
        x: u32 = 0,
        y: u32 = 0,
    };

    var list: Array2D(Tile, 3, 4) = .init();
    var iter = list.iterator();
    while (iter.next()) |e| {
        // Initialize all tiles
        e.t.* = .{};
        std.log.err("{}, {}: {}", .{ e.x, e.y, e.t });
    }
}
