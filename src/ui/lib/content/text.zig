const std = @import("std");
const Allocator = std.mem.Allocator;

const sdl = @import("sdl3");
const ttf = sdl.ttf;

const Color = @import("../../../color.zig").Color;
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

const Image = struct {
    engine: ttf.RendererTextEngine,
    font: ttf.Font,
    text: ttf.Text,
};

pub const ComponentText = struct {
    const Self = @This();

    content: TextContent,
    align_h: TextAlignment = .start,
    align_v: TextAlignment = .start,
    font: Font = .{},
    color: Color = .black,

    _image: ?Image = null,

    pub fn deinit(self: *Self) void {
        self.content.deinit();
        self.clearImage();
    }

    fn clearImage(self: *Self) void {
        if (self._image) |img| {
            img.text.deinit();
            img.font.deinit();
            img.engine.deinit();
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
            const engine = ttf.RendererTextEngine.init(Game.renderer) catch unreachable;
            const f = ttf.Font.init(file_name, self.font.size) catch unreachable;
            const txt = ttf.Text.init(.{ .value = engine.value }, f, text) catch unreachable;
            txt.setColor(self.color.r, self.color.g, self.color.b, self.color.a) catch unreachable;
            @constCast(self)._image = .{
                .engine = engine,
                .font = f,
                .text = txt,
            };
        }
        return self._image;
    }

    pub fn render(self: *const Self, content_area: Insets) void {
        const img = self.ensureImage() orelse return;

        Game.renderer.setDrawColor(Color.blue.into()) catch unreachable;
        Game.renderer.renderRect(content_area.frect()) catch unreachable;
        ttf.drawRendererText(img.text, content_area.left, content_area.top) catch unreachable;
    }
};
