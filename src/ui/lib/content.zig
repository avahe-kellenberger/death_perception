const Insets = @import("./types.zig").Insets;

const ComponentText = @import("./content/text.zig").ComponentText;
const ComponentImage = @import("./content/image.zig").ComponentImage;
const ComponentSprite = @import("./content/sprite.zig").ComponentSprite;

pub const ComponentContent = union(enum) {
    const Self = @This();

    none,
    text: ComponentText,
    image: ComponentImage,
    sprite: ComponentSprite,

    pub fn init(self: *Self) void {
        switch (self.*) {
            .none => {},
            .text => |*t| t.init(),
            .image => |*i| i.init(),
            .sprite => |*s| s.init(),
        }
    }

    pub fn deinit(self: *Self) void {
        switch (self.*) {
            .none => {},
            .text => |*t| t.deinit(),
            .image => |*i| i.deinit(),
            .sprite => |*s| s.deinit(),
        }
    }

    pub fn render(self: *const Self, content_area: Insets) void {
        switch (self.*) {
            .none => {},
            .text => |*t| t.render(content_area),
            .image => |*i| i.render(content_area),
            .sprite => |*s| s.render(content_area),
        }
    }
};
