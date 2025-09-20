const std = @import("std");
const sdl = @import("sdl3");

const Spritesheet = @import("../../../spritesheet.zig").Spritesheet;
const Vector = @import("../../../math/vector.zig").Vector(f32);
const Game = @import("../../../game.zig");
const Insets = @import("../../../math/insets.zig").Insets;

pub const SpriteCoord = struct {
    x: u16,
    y: u16,

    pub fn xy(x: u16, y: u16) SpriteCoord {
        return .{ .x = x, .y = y };
    }
};

const SpriteTiles = struct {
    const Self = @This();

    coords: []const []const SpriteCoord,

    pub fn clone(coords: []const []const SpriteCoord) SpriteTiles {
        const rows = Game.alloc.dupe([]const SpriteCoord, coords) catch unreachable;
        for (rows) |*row| {
            row.* = Game.alloc.dupe(SpriteCoord, row.*) catch unreachable;
        }
        return .{ .coords = rows };
    }

    pub fn deinit(self: *Self) void {
        Game.alloc.free(self.coords);
        self.coords = &.{};
    }
};

const SpriteMode = union(enum) {
    single: SpriteCoord,
    tiled: SpriteTiles,
};

const SpriteAlignment = enum {
    start,
    center,
    end,
};

pub const ComponentSprite = struct {
    const Self = @This();

    sheet: Spritesheet,
    mode: SpriteMode,
    align_h: SpriteAlignment = .start,
    align_v: SpriteAlignment = .start,
    scale: Vector = .one,

    pub fn init(_: *Self) void {}

    pub fn deinit(self: *Self) void {
        switch (self.mode) {
            .tiled => |*tiles| {
                tiles.deinit();
            },
            else => {},
        }
    }

    pub fn render(self: *const Self, content_area: Insets) void {
        const img_size: Vector = switch (self.mode) {
            .single => self.sheet.sprite_size,
            .tiled => |tiles| self.sheet.sprite_size.mul(.{
                .x = @floatFromInt(tiles.coords[0].len), // columns
                .y = @floatFromInt(tiles.coords.len), // rows
            }),
        };
        const target_size = img_size.mul(self.scale);

        const x_left: f32 = switch (self.align_h) {
            .start => content_area.left,
            .center => content_area.center().x - (target_size.x / 2.0),
            .end => content_area.right - target_size.x,
        };
        const y_top: f32 = switch (self.align_v) {
            .start => content_area.top,
            .center => content_area.center().y - (target_size.y / 2.0),
            .end => content_area.bottom - target_size.y,
        };

        switch (self.mode) {
            .single => |coord| {
                Game.renderer.renderTexture(
                    self.sheet.texture,
                    self.sheet.xy(coord.x, coord.y),
                    .{
                        .x = x_left,
                        .y = y_top,
                        .w = self.sheet.sprite_size.x * self.scale.x,
                        .h = self.sheet.sprite_size.y * self.scale.y,
                    },
                ) catch unreachable;
            },
            .tiled => |tiles| {
                var x: f32 = x_left;
                var y: f32 = y_top;
                const w: f32 = self.sheet.sprite_size.x * self.scale.x;
                const h: f32 = self.sheet.sprite_size.y * self.scale.y;
                for (tiles.coords) |row| {
                    for (row) |coord| {
                        Game.renderer.renderTexture(
                            self.sheet.texture,
                            self.sheet.xy(coord.x, coord.y),
                            .{ .x = x, .y = y, .w = w, .h = h },
                        ) catch unreachable;
                        x += w;
                    }
                    x = x_left;
                    y += h;
                }
            },
        }
    }
};
