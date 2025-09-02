const std = @import("std");
const Allocator = std.mem.Allocator;

const sdl = @import("sdl3");
const Texture = sdl.render.Texture;
const FRect = sdl.rect.FRect;
const Size = @import("size.zig").Size;

pub const Spritesheet = struct {
    pub const Self = @This();

    alloc: Allocator,
    sheet: Texture,
    width: usize,
    height: usize,
    sprites: []FRect,
    sprite_size: Size(usize),

    pub fn init(alloc: Allocator, sheet: Texture, w: usize, h: usize) !Spritesheet {
        var result: Spritesheet = .{
            .alloc = alloc,
            .sheet = sheet,
            .width = w,
            .height = h,
            .sprites = try alloc.alloc(FRect, w * h),
            .sprite_size = .{
                .w = @divExact(sheet.getWidth(), w),
                .h = @divExact(sheet.getHeight(), h),
            },
        };

        for (0..h) |y| for (0..w) |x| {
            result.sprites[x + y * w] = .{
                .x = @as(f32, @floatFromInt(x * result.sprite_size.w)),
                .y = @as(f32, @floatFromInt(y * result.sprite_size.h)),
                .w = @floatFromInt(result.sprite_size.w),
                .h = @floatFromInt(result.sprite_size.h),
            };
        };
        return result;
    }

    pub fn deinit(self: *Self) void {
        self.alloc.free(self.sprites);
    }

    pub fn get(self: *Self, x: usize, y: usize) FRect {
        return self.sprites[x + y * self.width];
    }
};
