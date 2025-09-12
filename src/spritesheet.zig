const std = @import("std");
const Allocator = std.mem.Allocator;

const sdl = @import("sdl3");
const Texture = sdl.render.Texture;
const FRect = sdl.rect.FRect;

const Vector = @import("./math/vector.zig").Vector;

pub const Spritesheet = struct {
    pub const Self = @This();

    texture: Texture,
    columns: u16,
    rows: u16,
    sprite_size: Vector(f32),

    pub fn init(texture: Texture, columns: u16, rows: u16) Self {
        std.debug.assert(columns > 0);
        std.debug.assert(rows > 0);
        return .{
            .texture = texture,
            .columns = columns,
            .rows = rows,
            .sprite_size = .{
                .x = @floatFromInt(@divExact(texture.getWidth(), columns)),
                .y = @floatFromInt(@divExact(texture.getHeight(), rows)),
            },
        };
    }

    pub fn xy(self: *const Self, x: u16, y: u16) FRect {
        std.debug.assert(x < self.columns);
        std.debug.assert(y < self.rows);
        return .{
            .x = @as(f32, @floatFromInt(x)) * self.sprite_size.x,
            .y = @as(f32, @floatFromInt(y)) * self.sprite_size.y,
            .w = self.sprite_size.x,
            .h = self.sprite_size.y,
        };
    }

    pub fn index(self: *const Self, idx: u32) FRect {
        return self.xy(
            @intCast(idx % self.columns),
            @intCast(idx / self.columns),
        );
    }
};
