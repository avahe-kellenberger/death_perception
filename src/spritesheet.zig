const std = @import("std");
const Allocator = std.mem.Allocator;

const sdl = @import("sdl3");
const Surface = sdl.surface.Surface;
const IRect = sdl.rect.IRect;
const Size = @import("size.zig").Size;

pub const Spritesheet = struct {
    pub const Self = @This();

    alloc: Allocator,
    sheet: Surface,
    width: usize,
    height: usize,
    sprites: []IRect,
    sprite_size: Size(usize),

    pub fn init(alloc: Allocator, sheet: Surface, w: usize, h: usize) !Spritesheet {
        var result: Spritesheet = .{
            .alloc = alloc,
            .sheet = sheet,
            .width = w,
            .height = h,
            .sprites = try alloc.alloc(IRect, w * h),
            .sprite_size = .{
                .w = @divExact(sheet.getWidth(), w),
                .h = @divExact(sheet.getHeight(), h),
            },
        };

        for (0..h) |y| for (0..w) |x| {
            result.sprites[x + y * w] = .{
                .x = @as(i32, @intCast(x * result.sprite_size.w)),
                .y = @as(i32, @intCast(y * result.sprite_size.h)),
                .w = @intCast(result.sprite_size.w),
                .h = @intCast(result.sprite_size.h),
            };
        };
        return result;
    }

    pub fn deinit(self: *Self) void {
        self.alloc.free(self.sprites);
    }

    pub fn get(self: *Self, x: usize, y: usize) IRect {
        return self.sprites[x + y * self.width];
    }
};
