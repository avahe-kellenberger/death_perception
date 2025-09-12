const std = @import("std");
const Allocator = std.mem.Allocator;

const sdl = @import("sdl3");
const Texture = sdl.render.Texture;
const FRect = sdl.rect.FRect;

const Size = @import("size.zig").Size;

pub const Spritesheet = struct {
    pub const Self = @This();

    sheet: Texture,
    columns: u16,
    rows: u16,
    sprite_size: Size(f32),

    pub fn init(sheet: Texture, columns: u16, rows: u16) Self {
        std.debug.assert(columns > 0);
        std.debug.assert(rows > 0);
        return .{
            .sheet = sheet,
            .columns = columns,
            .rows = rows,
            .sprite_size = .{
                .w = @floatFromInt(@divExact(sheet.getWidth(), columns)),
                .h = @floatFromInt(@divExact(sheet.getHeight(), rows)),
            },
        };
    }

    pub fn xy(self: *const Self, x: u16, y: u16) FRect {
        std.debug.assert(x < self.columns);
        std.debug.assert(y < self.rows);
        return .{
            .x = @as(f32, @floatFromInt(x)) * self.sprite_size.w,
            .y = @as(f32, @floatFromInt(y)) * self.sprite_size.h,
            .w = self.sprite_size.w,
            .h = self.sprite_size.h,
        };
    }

    pub fn index(self: *const Self, idx: u32) FRect {
        return self.xy(
            @intCast(idx % self.columns),
            @intCast(idx / self.columns),
        );
    }
};
