const std = @import("std");
const sdl = @import("sdl3");
const Surface = sdl.surface.Surface;
const IRect = sdl.rect.IRect;
const Size = @import("size.zig").Size;

pub fn Spritesheet(comptime width: usize, comptime height: usize) type {
    return struct {
        pub const Self = @This();

        sheet: Surface,
        width: usize,
        height: usize,
        sprites: [width * height]IRect(i32),
        sprite_size: Size(usize),

        pub fn init(sheet: Surface) Spritesheet(width, height) {
            var result = .{
                .sheet = sheet,
                .sprite_size = .{
                    .width = @divExact(sheet.getWidth(), width),
                    .height = @divExact(sheet.getHeight(), height),
                },
            };

            for (0..height) |y| for (0..width) |x| {
                result.sprites[x + y * width] = .{
                    .x = x * result.sprite_size.w,
                    .y = y * result.sprite_size.h,
                    .w = result.sprite_size.w,
                    .h = result.sprite_size.h,
                };
            };

            return result;
        }

        pub fn get(self: *Self, x: usize, y: usize) IRect(i32) {
            return self.sprites[x + y * width];
        }
    };
}
