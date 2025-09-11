const sdl = @import("sdl3");

const Vector = @import("../../../math/vector.zig").Vector(f32);
const Game = @import("../../../game.zig");
const Insets = @import("../types.zig").Insets;

/// For details, see: https://developer.mozilla.org/en-US/docs/Web/CSS/object-fit
const ImageFit = enum {
    const Self = @This();

    none,
    contain,
    cover,
    fill,
    scale_down,

    pub fn scalar(self: *const Self, content_size: Vector, img_size: Vector, scale: f32) Vector {
        switch (self.*) {
            .none => return .init(scale, scale),
            .contain => {
                const scale_x = content_size.x / img_size.x;
                const scale_y = content_size.y / img_size.y;
                const min_scale = @min(scale_x, scale_y);
                return .init(min_scale, min_scale);
            },
            .cover => {
                const scale_x = content_size.x / img_size.x;
                const scale_y = content_size.y / img_size.y;
                const max_scale = @max(scale_x, scale_y);
                return .init(max_scale, max_scale);
            },
            .fill => {
                const scale_x = content_size.x / img_size.x;
                const scale_y = content_size.y / img_size.y;
                return .init(scale_x, scale_y);
            },
            .scale_down => {
                const scale_x = content_size.x / img_size.x;
                const scale_y = content_size.y / img_size.y;
                const min_scale = @min(scale, scale_x, scale_y);
                return .init(min_scale, min_scale);
            },
        }
    }
};

const ImageAlignment = enum {
    start,
    center,
    end,
};

pub const ComponentImage = struct {
    const Self = @This();

    file_path: [:0]const u8,
    scale_mode: sdl.surface.ScaleMode = .nearest,
    align_h: ImageAlignment = .start,
    align_v: ImageAlignment = .start,
    fit: ImageFit = .contain,
    scale: f32 = 1.0,

    _texture: ?sdl.render.Texture = null,

    pub fn init(self: *Self) void {
        _ = self.ensureImage();
    }

    pub fn deinit(self: *Self) void {
        self.clearImage();
    }

    fn clearImage(self: *Self) void {
        if (self._texture) |texture| {
            texture.deinit();
            self._texture = null;
        }
    }

    fn ensureImage(self: *const Self) ?sdl.render.Texture {
        if (self._texture == null) {
            @constCast(self)._texture = Game.loadTexture(self.file_path, self.scale_mode);
        }
        return self._texture;
    }

    pub fn render(self: *const Self, content_area: Insets) void {
        const img = self.ensureImage() orelse return;
        const img_size: Vector = .init(
            @floatFromInt(img.getWidth()),
            @floatFromInt(img.getHeight()),
        );
        const scale = self.fit.scalar(content_area.size(), img_size, self.scale);
        const target_size = img_size.mul(scale);

        const x_left: f32 = switch (self.align_h) {
            .start => content_area.left,
            .center => content_area.center().x - (target_size.x / 2.0),
            .end => content_area.right - target_size.x,
        };
        const y_top: f32 = switch (self.align_h) {
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
