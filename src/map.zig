const std = @import("std");
const Allocator = std.mem.Allocator;
const sdl = @import("sdl3");

const Array2D = @import("array_2d.zig").Array2D;

const Tile = struct {
    floor_image_index: i32 = -1,
    wall_image_index: i32 = -1,
    neighbor_bit_sum: u8,
    is_wall: bool,
};

pub fn Map(comptime width: u32, comptime height: u32) type {
    return struct {
        alloc: Allocator,

        arr: Array2D(Tile, width, height),

        pub fn init(alloc: Allocator) !Map {
            return .{
                .alloc = alloc,
                .arr = Array2D(Tile, width, height).init(),
            };
        }
    };
}
