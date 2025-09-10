const std = @import("std");
const Allocator = std.mem.Allocator;

const sdl = @import("sdl3");
const ttf = sdl.ttf;

const Color = @import("../../../color.zig").Color;
const Vector = @import("../../../math/vector.zig").Vector(f32);
const Game = @import("../../../game.zig");
const Insets = @import("../types.zig").Insets;

const TextContent = union(enum) {
    const Self = @This();

    borrowed: []const u8,
    owned: struct {
        data: []const u8,
        alloc: Allocator,
    },

    /// Borrow a string without taking ownership.
    pub fn borrow(data: []const u8) Self {
        return .{ .borrowed = data };
    }

    /// Take ownership of string data.
    pub fn take(data: []const u8, alloc: Allocator) Self {
        return .{
            .owned = .{
                .data = data,
                .alloc = alloc,
            },
        };
    }

    /// Use string data to create an owned copy.
    pub fn clone(data: []const u8, alloc: Allocator) Self {
        return .take(alloc.dupe(u8, data), alloc);
    }

    /// Free string data if owned.
    pub fn deinit(self: *Self) void {
        if (self.* == .owned) {
            self.owned.alloc.free(self.owned.data);
        }
    }

    /// Access a read-only reference to the string data.
    pub fn ref(self: *const Self) []const u8 {
        return switch (self.*) {
            .borrowed => |d| d,
            .owned => |o| o.data,
        };
    }
};

const TextAlignment = enum {
    start,
    center,
    end,
};

const Font = struct {
    file: []const u8 = "./assets/fonts/kennypixel.ttf",
    size: f32 = 64.0,
};

const Image = sdl.render.Texture;

pub const ComponentText = struct {
    const Self = @This();

    content: TextContent,
    align_h: TextAlignment = .start,
    align_v: TextAlignment = .start,
    fit: bool = false,
    font: Font = .{},
    color: Color = .black,

    _image: ?Image = null,

    pub fn deinit(self: *Self) void {
        self.content.deinit();
        self.clearImage();
    }

    fn clearImage(self: *Self) void {
        if (self._image) |img| {
            img.deinit();
            self._image = null;
        }
    }

    fn ensureImage(self: *const Self) ?Image {
        const text = self.content.ref();
        if (text.len == 0) {
            @constCast(self).clearImage();
        } else if (self._image == null) {
            // Create new SDL objects
            const file_name = std.heap.smp_allocator.dupeZ(u8, self.font.file) catch unreachable;
            defer std.heap.smp_allocator.free(file_name);
            const f = ttf.Font.init(file_name, self.font.size) catch unreachable;
            defer f.deinit();
            const surface = f.renderTextBlendedWrapped(text, self.color.ttf(), 0) catch unreachable;
            defer surface.deinit();
            const texture = Game.renderer.createTextureFromSurface(surface) catch unreachable;

            @constCast(self)._image = texture;
        }
        return self._image;
    }

    pub fn render(self: *const Self, content_area: Insets) void {
        const img = self.ensureImage() orelse return;

        const img_size: Vector = .init(
            @floatFromInt(img.getWidth()),
            @floatFromInt(img.getHeight()),
        );

        const target_size: Vector = if (self.fit) target_size: {
            const scale_x: f32 = content_area.width() / img_size.x;
            const scale_y: f32 = content_area.height() / img_size.y;
            const min_scale: f32 = @min(scale_x, scale_y);
            break :target_size img_size.scale(min_scale);
        } else img_size;

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

        Game.renderer.renderTexture(img, .{
            .x = 0,
            .y = 0,
            .w = img_size.x,
            .h = img_size.y,
        }, .{
            .x = x_left,
            .y = y_top,
            .w = target_size.x,
            .h = target_size.y,
        }) catch unreachable;
    }
};
