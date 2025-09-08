const Insets = @import("../types.zig").Insets;

pub const ComponentSprite = struct {
    const Self = @This();

    // TODO

    pub fn deinit(_: *Self) void {}

    pub fn render(self: *const Self, content_area: Insets) void {
        _ = self;
        _ = content_area;
    }
};
